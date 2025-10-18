defmodule Craftplan.InventoryForecasting do
  @moduledoc """
  Module for inventory forecasting operations
  """

  alias Craftplan.Orders

  @doc """
  Prepares materials requirements for a given date range.
  Uses Ash to efficiently query only orders within the date range.
  """
  def prepare_materials_requirements(days_range, actor \\ nil) when is_list(days_range) do
    orders = load_orders_for_forecast(days_range, actor)
    materials_by_day_data = load_materials_requirements(days_range, orders)

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
    initial_balance = material.current_stock || Decimal.new(0)

    Enum.map_reduce(quantities, initial_balance, fn {day_quantity, _day}, acc_balance ->
      new_balance = Decimal.sub(acc_balance, day_quantity)
      {acc_balance, new_balance}
    end)
  end

  @doc """
  Gets material requirements by day for the given date range
  """
  def load_materials_requirements(days_range, orders) do
    materials_by_day =
      Enum.flat_map(orders, fn order ->
        day = DateTime.to_date(order.delivery_date)

        Enum.flat_map(order.items, fn
          %{product: %{recipe: nil}} ->
            []

          %{product: %{recipe: recipe}, quantity: quantity} ->
            Enum.map(recipe.components, fn component ->
              {day, component.material, Decimal.mult(component.quantity, quantity)}
            end)
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
            |> Enum.reduce(Decimal.new(0), fn {_, qty}, acc -> Decimal.add(acc, qty) end)

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
    Enum.reduce(day_quantities, Decimal.new(0), fn {quantity, _}, acc ->
      Decimal.add(acc, quantity)
    end)
  end

  @doc """
  Gets material usage details for a specific material on a specific date
  """
  def get_material_usage_details(material, orders) do
    order_items_using_material =
      for order <- orders,
          item <- order.items,
          item.product.recipe != nil,
          component <- item.product.recipe.components,
          component.material.id == material.id do
        material_quantity = Decimal.mult(component.quantity, item.quantity)

        %{
          order: %{reference: order.reference},
          product: item.product,
          quantity: material_quantity
        }
      end

    order_items_using_material
    |> Enum.group_by(& &1.product)
    |> Enum.map(fn {product, items} ->
      total_quantity = Enum.reduce(items, Decimal.new(0), &Decimal.add(&2, &1.quantity))
      {product, %{total_quantity: total_quantity, order_items: items}}
    end)
    |> Enum.sort_by(fn {product, _} -> product.name end)
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
            {Decimal.new(0), Decimal.new(0)}

          day_index ->
            {quantity, _} = Enum.at(material_data.quantities, day_index)
            balance = Enum.at(material_data.balance_cells, day_index)
            {quantity, balance}
        end

      nil ->
        {Decimal.new(0), Decimal.new(0)}
    end
  end
end
