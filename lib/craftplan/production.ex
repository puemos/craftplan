defmodule Craftplan.Production do
  @moduledoc """
  Domain helpers for production planning, keeping LiveViews thin.

  Uses Ash reads and prepares for filtering/range selection; grouping and
  aggregation are performed in Elixir for simplicity (pure Ash prepare path).
  """

  alias Craftplan.Inventory
  alias Craftplan.InventoryForecasting
  alias Craftplan.Orders

  @type days_range :: [Date.t()]

  @doc """
  Fetch orders and dependent associations for a given `days_range`.
  Kept generic so UI can derive any presentation.
  """
  def fetch_orders_in_range(time_zone, days_range, opts \\ []) do
    {start_dt, end_dt} = range_to_datetimes(days_range, time_zone)

    default_load = [
      :reference,
      :status,
      customer: [:full_name],
      items: [
        :quantity,
        :status,
        :consumed_at,
        product: [
          :name,
          :max_daily_quantity,
          active_bom: [:rollup]
        ]
      ]
    ]

    Orders.list_orders!(
      %{delivery_date_start: start_dt, delivery_date_end: end_dt},
      load: Keyword.get(opts, :load, default_load),
      actor: Keyword.get(opts, :actor)
    )
  end

  @doc """
  Convert a `days_range` into {start_dt, end_dt} boundaries in the given time zone.
  """
  def range_to_datetimes(days_range, time_zone) do
    start_dt = days_range |> List.first() |> DateTime.new!(~T[00:00:00], time_zone)
    end_dt = days_range |> List.last() |> DateTime.new!(~T[23:59:59], time_zone)
    {start_dt, end_dt}
  end

  @doc """
  Build production items grouped by day and product from a list of orders.
  Output: list of tuples `{day :: Date.t(), product, [%{id, product, quantity, status, consumed_at, order}]}`.
  """
  def build_production_items(orders) do
    Enum.flat_map(orders, fn order ->
      day = DateTime.to_date(order.delivery_date)

      order.items
      |> Enum.group_by(& &1.product)
      |> Enum.map(fn {product, items} ->
        group_items =
          Enum.map(items, fn item ->
            %{
              id: item.id,
              product: product,
              quantity: item.quantity,
              status: item.status,
              consumed_at: item.consumed_at,
              order: order
            }
          end)

        {day, product, group_items}
      end)
    end)
  end

  @doc """
  Quantities per day per product for a given range, from `production_items`.
  Returns a list of %{day: Date.t(), product: product, qty: Decimal.t(), max: integer}.
  """
  def quantities_by_product_day(days_range, production_items) do
    Enum.flat_map(days_range, fn day ->
      production_items
      |> Enum.filter(fn {d, _p, _i} -> Date.compare(d, day) == :eq end)
      |> Enum.group_by(fn {_d, p, _i} -> p end, fn {_d, _p, i} -> i end)
      |> Enum.map(fn {product, groups} ->
        qty = groups |> List.flatten() |> total_quantity()
        %{day: day, product: product, qty: qty, max: product.max_daily_quantity || 0}
      end)
    end)
  end

  @doc """
  Count orders per day for a given list of orders (already filtered by range).
  Returns list of %{day: Date.t(), count: non_neg_integer}.
  """
  def orders_count_by_day(days_range, orders) do
    orders_by_day = Enum.group_by(orders, fn o -> DateTime.to_date(o.delivery_date) end)

    Enum.map(days_range, fn day -> %{day: day, count: length(Map.get(orders_by_day, day, []))} end)
  end

  @doc """
  Determine shortages from a `materials_requirements` data structure for all days in range.
  Returns list of %{day, material, required, opening, ending} rows.
  """
  def material_shortages(materials_requirements) do
    materials_requirements
    |> Enum.flat_map(fn {material, data} ->
      data.quantities
      |> Enum.with_index()
      |> Enum.flat_map(fn {{required, d}, idx} ->
        opening = Enum.at(data.balance_cells, idx) || Decimal.new(0)
        ending = Decimal.sub(opening, required)

        if Decimal.compare(ending, Decimal.new(0)) == :lt do
          [%{day: d, material: material, required: required, opening: opening, ending: ending}]
        else
          []
        end
      end)
    end)
    |> Enum.sort_by(fn r -> {r.day, r.material.name} end)
  end

  @doc """
  Orders list for a specific date (used by UI for "Orders Today").
  The UI can choose any date; not restricted to today.
  """
  def orders_for_date(time_zone, date) do
    start_dt = DateTime.new!(date, ~T[00:00:00], time_zone)
    end_dt = DateTime.new!(date, ~T[23:59:59], time_zone)

    Orders.list_orders!(
      %{delivery_date_start: start_dt, delivery_date_end: end_dt},
      load: [:total_cost, :reference, customer: [:full_name]]
    )
  end

  @doc """
  Outstanding quantities by product for a specific date from `production_items`.
  Returns list of %{product, todo, in_progress}.
  """
  def outstanding_by_product_for_date(date, production_items) do
    production_items
    |> Enum.filter(fn {d, _p, _i} -> Date.compare(d, date) == :eq end)
    |> Enum.group_by(fn {_d, p, _i} -> p end, fn {_d, _p, i} -> i end)
    |> Enum.map(fn {product, groups} ->
      items = List.flatten(groups)
      todo = items |> Enum.filter(&(&1.status == :todo)) |> total_quantity()
      in_progress = items |> Enum.filter(&(&1.status == :in_progress)) |> total_quantity()
      %{product: product, todo: todo, in_progress: in_progress}
    end)
    |> Enum.sort_by(fn r -> r.product.name end)
  end

  @doc """
  Find a material by ID using Inventory domain.
  """
  def find_material!(material_id), do: Inventory.get_material_by_id!(material_id)

  @doc """
  Compute quantity and opening balance for a given material/date from the
  previously prepared `materials_requirements` list.
  """
  def material_day_info(material, date, materials_requirements) do
    InventoryForecasting.get_material_day_info(material, date, materials_requirements)
  end

  @doc """
  Build usage details for a material on a date (groups by product) using Ash reads.
  """
  def material_usage_details(time_zone, date, material, actor \\ nil) do
    {start_dt, end_dt} =
      {DateTime.new!(date, ~T[00:00:00], time_zone), DateTime.new!(date, ~T[23:59:59], time_zone)}

    orders =
      Orders.list_orders!(
        %{delivery_date_start: start_dt, delivery_date_end: end_dt},
        actor: actor,
        load: [
          :reference,
          items: [
            :quantity,
            product: [:name, active_bom: [:rollup]]
          ]
        ]
      )

    InventoryForecasting.get_material_usage_details(material, orders, actor)
  end

  # helpers
  defp total_quantity(items) do
    Enum.reduce(items, Decimal.new(0), fn item, acc -> Decimal.add(acc, item.quantity) end)
  end
end
