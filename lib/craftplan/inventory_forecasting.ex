defmodule Craftplan.InventoryForecasting do
  @moduledoc """
  Module for inventory forecasting operations
  """

  import Ash.Expr

  alias Ash.NotLoaded
  alias Craftplan.Inventory.ForecastRow
  alias Craftplan.Inventory.Material
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

          item
          |> per_unit_requirements(actor)
          |> Enum.map(fn {material_id, per_unit} ->
            {day, material_id, D.mult(per_unit, quantity)}
          end)
        end)
      end)

    material_lookup =
      materials_by_day
      |> Enum.map(fn {_, material_id, _} -> material_id end)
      |> Enum.reject(&is_nil/1)
      |> Enum.uniq()
      |> load_materials(actor)

    materials_by_day
    |> Enum.reject(fn {_, material_id, _} -> is_nil(material_id) end)
    |> Enum.group_by(
      fn {_, material_id, _} -> material_id end,
      fn {day, _material_id, quantity} -> {day, quantity} end
    )
    |> Enum.map(fn {material_id, day_quantities} ->
      material = Map.fetch!(material_lookup, material_id)

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
  def get_material_usage_details(material, orders, actor \\ nil) do
    orders
    |> Enum.flat_map(fn order ->
      Enum.flat_map(order.items, fn item ->
        quantity = item.quantity || D.new(0)

        item
        |> per_unit_requirements(actor)
        |> Enum.filter(fn {material_id, _} -> material_id == material.id end)
        |> Enum.map(fn {_material_id, per_unit} ->
          %{
            order: %{reference: order.reference},
            product: item.product,
            quantity: D.mult(per_unit, quantity)
          }
        end)
      end)
    end)
    |> Enum.group_by(& &1.product)
    |> Enum.map(fn {product, items} ->
      total_quantity = Enum.reduce(items, D.new(0), fn item, acc -> D.add(acc, item.quantity) end)
      {product, %{total_quantity: total_quantity, order_items: items}}
    end)
    |> Enum.sort_by(fn {product, _} -> product.name end)
  end

  @doc """
  Gets info about a specific material on a specific day from the forecast data
  """
  def get_material_day_info(material, date, materials_requirements) do
    with {_, material_data} <-
           Enum.find(materials_requirements, fn {m, _} -> m.id == material.id end),
         {:ok, day_index} <- find_day_index(material_data.quantities, date),
         {:ok, {quantity, _}} <- Enum.fetch(material_data.quantities, day_index) do
      balance = Enum.at(material_data.balance_cells, day_index)
      {quantity, balance || D.new(0)}
    else
      _ -> {D.new(0), D.new(0)}
    end
  end

  defp per_unit_requirements(item, actor) do
    case rollup_components_map(item) do
      {:ok, map} ->
        Enum.map(map, fn {material_id, quantity_str} ->
          {material_id, D.new(quantity_str)}
        end)

      :error ->
        item
        |> components_for_item(actor)
        |> Enum.filter(&(&1.component_type == :material))
        |> Enum.map(fn component ->
          material_id = component.material && component.material.id
          {material_id, component.quantity}
        end)
        |> Enum.reject(fn {material_id, _} -> is_nil(material_id) end)
    end
  end

  defp rollup_components_map(%{product: %{active_bom: %{rollup: %{} = rollup}}}) do
    case Map.get(rollup, :components_map) do
      %{} = map when map_size(map) > 0 -> {:ok, map}
      _ -> :error
    end
  end

  defp rollup_components_map(_), do: :error

  @doc """
  Builds rich forecast rows ready for owner metrics consumption.
  """
  def owner_grid_rows(days_range, opts \\ [], actor \\ nil) when is_list(days_range) do
    settings = safe_get_settings()

    service_level =
      Keyword.get(opts, :service_level) ||
        safe_decimal_to_float(settings.forecast_default_service_level, 0.95)

    service_level_z = service_level_to_z(service_level)
    lookback_days = Keyword.get(opts, :lookback_days) || settings.forecast_lookback_days || 42

    # Extract forecast weights - prefer opts over settings
    actual_weight =
      Keyword.get(opts, :actual_weight) ||
        safe_decimal_to_float(settings.forecast_actual_weight, 0.6)

    planned_weight =
      Keyword.get(opts, :planned_weight) ||
        safe_decimal_to_float(settings.forecast_planned_weight, 0.4)

    minimum_samples =
      Keyword.get(opts, :min_samples) || settings.forecast_min_samples || 10

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
          projected_balances: projected_balances,
          actual_weight: actual_weight,
          planned_weight: planned_weight,
          minimum_samples: minimum_samples
        }
      end)

    ForecastRow
    |> Ash.Query.for_read(:owner_grid_metrics, %{rows: rows})
    |> Ash.read!(actor: actor)
  end

  defp projected_closing_balances(day_quantities, initial_on_hand) do
    day_quantities
    |> Enum.map_reduce(initial_on_hand, fn {quantity, day}, balance ->
      closing = Money.sub!(balance, quantity)
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
    _ ->
      %{
        lead_time_days: 0,
        forecast_lookback_days: 42,
        forecast_actual_weight: D.new("0.6"),
        forecast_planned_weight: D.new("0.4"),
        forecast_min_samples: 10,
        forecast_default_service_level: D.new("0.95"),
        forecast_default_horizon_days: 14
      }
  end

  defp safe_decimal_to_float(nil, default), do: default
  defp safe_decimal_to_float(%D{} = decimal, _default), do: D.to_float(decimal)
  defp safe_decimal_to_float(value, _default) when is_float(value), do: value
  defp safe_decimal_to_float(value, _default) when is_integer(value), do: value * 1.0
  defp safe_decimal_to_float(_, default), do: default

  defp service_level_to_z(0.9), do: 1.28
  defp service_level_to_z(0.95), do: 1.65
  defp service_level_to_z(0.975), do: 1.96
  defp service_level_to_z(0.99), do: 2.33

  defp service_level_to_z(value) when is_float(value) and value > 0 do
    # Default to 95% when unrecognised
    service_level_to_z(0.95)
  end

  defp components_for_item(item, actor) do
    case active_bom_components(item, actor) do
      {:ok, components} -> components
      _ -> fallback_components(item.product_id, actor)
    end
  end

  defp active_bom_components(%{product: %{active_bom: %{} = bom}}, actor) do
    case Map.get(bom, :components) do
      components when is_list(components) ->
        {:ok, components}

      %NotLoaded{} ->
        if actor do
          bom =
            Ash.load!(bom, [components: [material: [:name, :unit, :current_stock]]], actor: actor)

          {:ok, Map.get(bom, :components, [])}
        else
          :error
        end

      _ ->
        :error
    end
  end

  defp active_bom_components(_, _), do: :error

  defp fallback_components(nil, _actor), do: []

  defp fallback_components(product_id, actor) do
    product_id
    |> latest_bom(actor)
    |> case do
      nil -> []
      bom -> ensure_components_loaded(bom, actor)
    end
  end

  defp latest_bom(nil, _actor), do: nil

  defp latest_bom(product_id, actor) do
    %{product_id: product_id}
    |> Craftplan.Catalog.list_boms_for_product!(actor: actor)
    |> List.first()
  end

  defp ensure_components_loaded(%{components: %NotLoaded{}} = bom, actor) do
    bom
    |> Ash.load!([components: [material: [:name, :unit, :current_stock]]], actor: actor)
    |> Map.get(:components, [])
  end

  defp ensure_components_loaded(%{components: components}, _actor) when is_list(components), do: components

  defp ensure_components_loaded(_bom, _actor), do: []

  defp load_materials([], _actor), do: %{}

  defp load_materials(ids, actor) do
    Material
    |> Ash.Query.filter(expr(id in ^ids))
    |> Ash.Query.load([:name, :unit, :current_stock])
    |> Ash.read!(actor: actor)
    |> Map.new(&{&1.id, &1})
  end

  defp find_day_index(quantities, date) do
    case Enum.find_index(quantities, fn {_, d} -> Date.compare(d, date) == :eq end) do
      nil -> {:error, :not_found}
      idx -> {:ok, idx}
    end
  end
end
