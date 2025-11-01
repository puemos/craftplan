defmodule Craftplan.InventoryForecasting do
  @moduledoc """
  Module for inventory forecasting operations
  """

  alias Craftplan.Inventory.ForecastRow
  alias Craftplan.Inventory.PurchaseOrderItem
  alias Craftplan.Orders
  alias Craftplan.Settings
  alias Decimal, as: D

  require Ash.Query

  @doc """
  Prepares materials requirements for a given date range.
  Uses Ash to efficiently query only orders within the date range.
  """
  def prepare_materials_requirements(days_range, actor \\ nil) when is_list(days_range) do
    orders = load_orders_for_forecast(days_range, actor)
    materials_by_day_data = load_materials_requirements(days_range, orders, actor)

    Enum.map(materials_by_day_data, fn {material, quantities} ->
      total_quantity = total_material_quantity(quantities)
      {balance_cells, final_balance} = calculate_material_balances(material, quantities)

      {material,
       %{
         quantities: quantities,
         total_quantity: total_quantity,
         balance_cells: balance_cells,
         final_balance: final_balance
       }}
    end)
  end

  # Loads orders for forecasting using the optimized :for_forecast read action.
  # Only loads orders within the date range with all necessary relationships.
  defp load_orders_for_forecast(days_range, actor) when is_list(days_range) do
    start_date = Enum.min(days_range, Date)
    end_date = Enum.max(days_range, Date)

    Orders.Order
    |> Ash.Query.for_read(:for_forecast, %{start_date: start_date, end_date: end_date}, actor: actor)
    |> Ash.read!()
  end

  @doc """
  Calculates material balances for each day in the forecast
  """
  def calculate_material_balances(material, quantities) do
    initial_balance = material.current_stock || D.new(0)

    Enum.map_reduce(quantities, initial_balance, fn {day_quantity, _day}, acc_balance ->
      new_balance = D.sub(acc_balance, day_quantity)
      {acc_balance, new_balance}
    end)
  end

  @doc """
  Gets material requirements by day for the given date range
  """
  def load_materials_requirements(days_range, orders, actor) do
    materials_by_day =
      Enum.flat_map(orders, fn order ->
        day = DateTime.to_date(order.delivery_date)

        Enum.flat_map(order.items, fn item ->
          quantity = item.quantity || D.new(0)

          if item.product.active_bom && item.product.active_bom.components != nil do
            item.product.active_bom.components
            |> Enum.filter(&(&1.component_type == :material))
            |> Enum.map(fn component ->
              {day, component.material, D.mult(component.quantity, quantity)}
            end)
          else
            # Fallback to latest BOM for the product
            bom =
              %{product_id: item.product_id}
              |> Craftplan.Catalog.list_boms_for_product!(actor: actor)
              |> List.first()

            if bom do
              bom =
                Ash.load!(bom, [components: [material: [:name, :unit, :current_stock]]], actor: actor)

              bom.components
              |> Enum.filter(&(&1.component_type == :material))
              |> Enum.map(fn component ->
                {day, component.material, D.mult(component.quantity, quantity)}
              end)
            else
              []
            end
          end
        end)
      end)

    materials_by_day
    |> Enum.group_by(
      fn {_, material, _} -> material end,
      fn {day, _, quantity} -> {day, quantity} end
    )
    |> Enum.map(fn {material, day_quantities} ->
      quantities_by_day =
        Enum.map(days_range, fn day ->
          day_quantity =
            day_quantities
            |> Enum.filter(fn {qty_day, _} -> Date.compare(qty_day, day) == :eq end)
            |> Enum.reduce(D.new(0), fn {_, qty}, acc -> D.add(acc, qty) end)

          {day_quantity, day}
        end)

      {material, quantities_by_day}
    end)
    |> Enum.sort_by(fn {material, _} -> material.name end)
  end

  @doc """
  Calculates total quantity needed for a material across all days
  """
  def total_material_quantity(day_quantities) do
    Enum.reduce(day_quantities, D.new(0), fn {quantity, _}, acc ->
      D.add(acc, quantity)
    end)
  end

  @doc """
  Gets material usage details for a specific material on a specific date
  """
  def get_material_usage_details(material, orders) do
    order_items_using_material =
      for order <- orders,
          item <- order.items,
          {_component, material_quantity} <- material_usages_for_item(item, material) do
        %{
          order: %{reference: order.reference},
          product: item.product,
          quantity: material_quantity
        }
      end

    order_items_using_material
    |> Enum.group_by(& &1.product)
    |> Enum.map(fn {product, items} ->
      total_quantity = Enum.reduce(items, D.new(0), &D.add(&2, &1.quantity))
      {product, %{total_quantity: total_quantity, order_items: items}}
    end)
    |> Enum.sort_by(fn {product, _} -> product.name end)
  end

  defp material_usages_for_item(item, material) do
    quantity = item.quantity || D.new(0)

    if item.product.active_bom && item.product.active_bom.components != nil do
      item.product.active_bom.components
      |> Enum.filter(&(&1.component_type == :material))
      |> Enum.filter(&(Map.get(&1.material, :id) == material.id))
      |> Enum.map(fn c -> {c, D.mult(c.quantity, quantity)} end)
    else
      []
    end
  end

  @doc """
  Gets info about a specific material on a specific day from the forecast data
  """
  def get_material_day_info(material, date, materials_requirements) do
    case Enum.find(materials_requirements, fn {m, _} -> m.id == material.id end) do
      {_, material_data} ->
        case Enum.find_index(material_data.quantities, fn {_, d} ->
               Date.compare(d, date) == :eq
             end) do
          nil ->
            {D.new(0), D.new(0)}

          day_index ->
            {quantity, _} = Enum.at(material_data.quantities, day_index)
            balance = Enum.at(material_data.balance_cells, day_index)
            {quantity, balance}
        end

      nil ->
        {D.new(0), D.new(0)}
    end
  end

  @doc """
  Builds rich forecast rows ready for owner metrics consumption.
  """
  def owner_grid_rows(days_range, opts \\ [], actor \\ nil) when is_list(days_range) do
    service_level = Keyword.get(opts, :service_level, 0.95)
    service_level_z = service_level_to_z(service_level)
    lookback_days = Keyword.get(opts, :lookback_days, 42)

    materials_requirements = prepare_materials_requirements(days_range, actor)

    past_range = build_past_range(days_range, lookback_days)
    past_orders = maybe_load_orders(past_range, actor)

    actual_usage_map =
      past_range
      |> load_materials_requirements(past_orders, actor)
      |> Map.new(fn {material, quantities} ->
        {material.id, Enum.map(quantities, fn {quantity, _day} -> quantity end)}
      end)

    on_order_map = open_purchase_orders_by_material(actor)
    settings = safe_get_settings()
    default_lead_time = settings.lead_time_days || 0

    rows =
      Enum.map(materials_requirements, fn {material, data} ->
        on_hand = material.current_stock || D.new(0)
        on_order = Map.get(on_order_map, material.id, D.new(0))

        planned_usage = Enum.map(data.quantities, fn {quantity, _day} -> quantity end)

        projected_balances =
          data.quantities
          |> projected_closing_balances(on_hand)
          |> Enum.map(fn {day, balance} -> %{date: day, balance: balance} end)

        %{
          material_id: material.id,
          material_name: material.name,
          on_hand: on_hand,
          on_order: on_order,
          lead_time_days: default_lead_time,
          service_level_z: D.from_float(service_level_z),
          pack_size: D.new(1),
          max_cover_days: nil,
          actual_usage: Map.get(actual_usage_map, material.id, []),
          planned_usage: planned_usage,
          projected_balances: projected_balances
        }
      end)

    ForecastRow
    |> Ash.Query.for_read(:owner_grid_metrics, %{rows: rows})
    |> Ash.read!(actor: actor)
  end

  defp projected_closing_balances(day_quantities, initial_on_hand) do
    day_quantities
    |> Enum.map_reduce(initial_on_hand, fn {quantity, day}, balance ->
      closing = D.sub(balance, quantity)
      {{day, closing}, closing}
    end)
    |> elem(0)
  end

  defp build_past_range(_days_range, lookback_days) when lookback_days <= 0, do: []

  defp build_past_range(days_range, lookback_days) do
    start_day = Enum.min(days_range, Date)

    start_day
    |> Stream.iterate(&Date.add(&1, -1))
    |> Stream.drop(1)
    |> Enum.take(lookback_days)
    |> Enum.reverse()
  end

  defp maybe_load_orders([], _actor), do: []
  defp maybe_load_orders(days_range, actor), do: load_orders_for_forecast(days_range, actor)

  defp open_purchase_orders_by_material(actor) do
    PurchaseOrderItem
    |> Ash.Query.load(:purchase_order)
    |> Ash.read!(actor: actor)
    |> Enum.filter(fn item ->
      case item.purchase_order do
        %{status: :received} -> false
        _ -> true
      end
    end)
    |> Enum.group_by(& &1.material_id, fn item -> item.quantity end)
    |> Map.new(fn {material_id, quantities} ->
      total =
        Enum.reduce(quantities, D.new(0), fn qty, acc ->
          D.add(acc, qty || D.new(0))
        end)

      {material_id, total}
    end)
  end

  defp safe_get_settings do
    Settings.get_settings!()
  rescue
    _ -> %{lead_time_days: 0}
  end

  defp service_level_to_z(0.9), do: 1.28
  defp service_level_to_z(0.95), do: 1.65
  defp service_level_to_z(0.975), do: 1.96
  defp service_level_to_z(0.99), do: 2.33

  defp service_level_to_z(value) when is_float(value) and value > 0 do
    # Default to 95% when unrecognised
    service_level_to_z(0.95)
  end
end
