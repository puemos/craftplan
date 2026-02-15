defmodule Craftplan.Production do
  @moduledoc """
  Domain helpers for production planning, keeping LiveViews thin.

  Uses Ash reads and prepares for filtering/range selection; grouping and
  aggregation are performed in Elixir for simplicity (pure Ash prepare path).
  """

  import Ash.Expr

  alias Craftplan.Inventory
  alias Craftplan.InventoryForecasting
  alias Craftplan.Orders
  alias Craftplan.Orders.OrderItem
  alias Craftplan.Orders.OrderItemBatchAllocation
  alias Craftplan.Orders.ProductionBatch
  alias Decimal, as: D

  require Ash.Query

  @batch_item_load [
    :quantity,
    :status,
    :unit_price,
    :unit_cost,
    :material_cost,
    :labor_cost,
    :overhead_cost,
    :consumed_at,
    :inserted_at,
    :bom,
    product: [:name, :sku],
    order: [
      :reference,
      :delivery_date,
      customer: [:full_name, :email, :phone]
    ],
    order_item_lots: [
      :quantity_used,
      lot: [
        :lot_code,
        :expiry_date,
        :received_at,
        :current_stock,
        material: [:name, :sku, :unit],
        supplier: [:name]
      ]
    ]
  ]

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
        :batch_code,
        :production_batch_id,
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
              batch_code: item.batch_code,
              production_batch_id: item.production_batch_id,
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
        opening = Enum.at(data.balance_cells, idx) || D.new(0)
        ending = D.sub(opening, required)

        if D.compare(ending, D.new(0)) == :lt do
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
      load: [:reference, customer: [:full_name]]
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

  @doc """
  Returns production batches filtered by status and product name.
  """
  def list_batches(filters \\ %{}, opts \\ []) do
    args =
      %{}
      |> then(fn args ->
        case Map.get(filters, :status) do
          nil -> args
          [] -> args
          statuses -> Map.put(args, :status, Enum.map(statuses, &String.to_existing_atom/1))
        end
      end)
      |> then(fn args ->
        case Map.get(filters, :product_name) do
          nil -> args
          "" -> args
          name -> Map.put(args, :product_name, name)
        end
      end)

    Orders.list_production_batches_filtered!(args, opts)
  end

  @doc """
  Returns recent batches (newest first) with summary metadata for listing pages.
  """
  def list_recent_batches(limit \\ 20, opts \\ []) when limit > 0 do
    actor = Keyword.get(opts, :actor)
    currency = Craftplan.Settings.get_settings!().currency
    search_limit = max(limit * 5, limit)

    OrderItem
    |> Ash.Query.new()
    |> Ash.Query.filter(expr(not is_nil(batch_code)))
    |> Ash.Query.sort(inserted_at: :desc)
    |> Ash.Query.select([:batch_code])
    |> Ash.Query.limit(search_limit)
    |> Ash.read!(actor: actor)
    |> Enum.reduce_while({[], MapSet.new()}, fn item, {acc, seen} ->
      code = item.batch_code

      cond do
        is_nil(code) ->
          {:cont, {acc, seen}}

        MapSet.member?(seen, code) ->
          {:cont, {acc, seen}}

        true ->
          report =
            batch_report!(code, actor: actor, currency: currency)

          summary = %{
            batch_code: code,
            product: report.product,
            produced_at: report.produced_at,
            totals: report.totals,
            order_count: length(report.orders)
          }

          new_acc = [summary | acc]
          new_seen = MapSet.put(seen, code)

          if length(new_acc) >= limit do
            {:halt, {new_acc, new_seen}}
          else
            {:cont, {new_acc, new_seen}}
          end
      end
    end)
    |> elem(0)
    |> Enum.reverse()
  rescue
    _ -> []
  end

  @doc """
  Builds a full report for a given `batch_code`, including order rows, material lots,
  and aggregate cost metrics. Raises if no order items exist for the code.
  """
  def batch_report!(batch_code, opts \\ []) do
    actor = Keyword.get(opts, :actor)
    currency = Keyword.get(opts, :currency)
    production_batch = maybe_load_production_batch(batch_code, actor)

    items =
      case batch_order_items_by_code(batch_code, actor) do
        [] -> batch_order_items_by_allocation(production_batch, actor)
        items -> items
      end

    if Enum.empty?(items) do
      raise ArgumentError, "no order items found for batch #{batch_code}"
    end

    product = resolve_batch_product(production_batch, items)
    bom = resolve_batch_bom(production_batch, items)
    produced_at = resolve_produced_at(production_batch, items)
    totals = summarize_batch(items, currency)
    lots = lot_rollup(items)
    materials = material_rollup_from_lots(lots)

    %{
      batch_code: batch_code,
      produced_at: produced_at,
      product: product,
      bom: bom,
      order_items: items,
      orders: batch_order_rows(items),
      totals: totals,
      lots: lots,
      materials: materials,
      production_batch: production_batch
    }
  end

  def summarize_batch(items, currency) do
    totals =
      Enum.reduce(
        items,
        %{
          quantity: D.new(0),
          material_cost: Money.new!(0, currency),
          labor_cost: Money.new!(0, currency),
          overhead_cost: Money.new!(0, currency)
        },
        fn item, acc ->
          %{
            quantity: D.add(acc.quantity, item.quantity || D.new(0)),
            material_cost: Money.add!(acc.material_cost, item.material_cost || Money.new!(0, currency)),
            labor_cost: Money.add!(acc.labor_cost, item.labor_cost || Money.new!(0, currency)),
            overhead_cost: Money.add!(acc.overhead_cost, item.overhead_cost || Money.new!(0, currency))
          }
        end
      )

    total_cost =
      totals.material_cost
      |> Money.add!(totals.labor_cost)
      |> Money.add!(totals.overhead_cost)

    unit_cost =
      case D.compare(totals.quantity, D.new(0)) do
        :eq -> Money.new!(0, currency)
        _ -> Money.div!(total_cost, totals.quantity)
      end

    totals
    |> Map.put(:total_cost, total_cost)
    |> Map.put(:unit_cost, unit_cost)
  end

  def batch_order_rows(items, currency \\ :usd) do
    items
    |> Enum.map(fn item ->
      order = item.order
      customer = order.customer

      line_total =
        Money.mult!(item.quantity || D.new(0), item.unit_price || Money.new!(0, currency))

      %{
        id: item.id,
        order: order,
        customer_name: customer && customer.full_name,
        quantity: item.quantity || D.new(0),
        status: item.status,
        line_total: line_total,
        unit_cost: item.unit_cost || Money.new!(0, currency),
        material_cost: item.material_cost || Money.new!(0, currency),
        labor_cost: item.labor_cost || Money.new!(0, currency),
        overhead_cost: item.overhead_cost || Money.new!(0, currency),
        consumed_at: item.consumed_at
      }
    end)
    |> Enum.sort_by(fn row -> row.order.reference end)
  end

  defp lot_rollup(items) do
    items
    |> Enum.flat_map(fn item ->
      Enum.map(item.order_item_lots || [], fn usage ->
        lot = usage.lot
        material = lot && lot.material
        supplier = lot && lot.supplier

        %{
          lot: lot,
          lot_code: lot && lot.lot_code,
          material: material,
          supplier: supplier,
          expiry_date: lot && lot.expiry_date,
          remaining: (lot && lot.current_stock) || D.new(0),
          quantity_used: usage.quantity_used || D.new(0),
          orders: [
            %{
              reference: item.order.reference,
              quantity: usage.quantity_used || D.new(0),
              customer_name: item.order.customer && item.order.customer.full_name
            }
          ]
        }
      end)
    end)
    |> Enum.reject(&is_nil(&1.lot))
    |> Enum.group_by(fn entry -> entry.lot.id end)
    |> Enum.map(fn {_lot_id, entries} ->
      first = hd(entries)

      total_used =
        Enum.reduce(entries, D.new(0), fn entry, acc ->
          D.add(acc, entry.quantity_used)
        end)

      orders = Enum.flat_map(entries, & &1.orders)

      %{
        lot: first.lot,
        lot_code: first.lot_code,
        material: first.material,
        supplier: first.supplier,
        expiry_date: first.expiry_date,
        remaining: first.remaining,
        quantity_used: total_used,
        orders: orders
      }
    end)
    |> Enum.sort_by(fn entry ->
      {
        (entry.material && entry.material.name) || "",
        entry.lot_code || ""
      }
    end)
  end

  defp material_rollup_from_lots([]), do: []

  defp material_rollup_from_lots(lots) do
    lots
    |> Enum.group_by(fn entry -> entry.material && entry.material.id end)
    |> Enum.map(fn {_, entries} ->
      material = entries |> hd() |> Map.get(:material)

      total =
        Enum.reduce(entries, D.new(0), fn entry, acc ->
          D.add(acc, entry.quantity_used)
        end)

      %{
        material: material,
        quantity_used: total,
        lots: entries
      }
    end)
    |> Enum.sort_by(fn entry -> (entry.material && entry.material.name) || "" end)
  end

  defp batch_order_items_by_code(batch_code, actor) do
    OrderItem
    |> Ash.Query.new()
    |> Ash.Query.filter(expr(batch_code == ^batch_code))
    |> Ash.Query.load(@batch_item_load)
    |> Ash.Query.sort(inserted_at: :asc)
    |> Ash.read!(actor: actor)
  end

  defp batch_order_items_by_allocation(nil, _actor), do: []

  defp batch_order_items_by_allocation(production_batch, actor) do
    allocation_item_ids =
      OrderItemBatchAllocation
      |> Ash.Query.filter(production_batch_id == ^production_batch.id)
      |> Ash.Query.select([:order_item_id])
      |> Ash.read!(actor: actor)
      |> Enum.map(& &1.order_item_id)

    case allocation_item_ids do
      [] ->
        []

      ids ->
        OrderItem
        |> Ash.Query.filter(expr(id in ^ids))
        |> Ash.Query.load(@batch_item_load)
        |> Ash.Query.sort(inserted_at: :asc)
        |> Ash.read!(actor: actor)
    end
  end

  defp maybe_load_production_batch(batch_code, actor) do
    case Orders.get_production_batch_by_code(%{batch_code: batch_code},
           actor: actor,
           load: [:product, :bom]
         ) do
      {:ok, %{} = batch} -> batch
      {:error, _} -> nil
      _ -> nil
    end
  end

  defp resolve_batch_product(%{product: %{} = product}, _items), do: product
  defp resolve_batch_product(_, [first | _]), do: first.product
  defp resolve_batch_product(_, _), do: nil

  defp resolve_batch_bom(%{bom: %{} = bom}, _items), do: bom
  defp resolve_batch_bom(_, [first | _]), do: first.bom
  defp resolve_batch_bom(_, _), do: nil

  defp resolve_produced_at(%{produced_at: produced_at}, _items) when not is_nil(produced_at), do: produced_at

  defp resolve_produced_at(_, items) do
    items
    |> Enum.flat_map(fn item -> [item.consumed_at, item.order.delivery_date] end)
    |> earliest_datetime()
  end

  defp earliest_datetime(datetimes) do
    datetimes
    |> Enum.reject(&is_nil/1)
    |> Enum.reduce(nil, fn dt, acc ->
      cond do
        is_nil(acc) -> dt
        DateTime.before?(dt, acc) -> dt
        true -> acc
      end
    end)
  end

  @doc """
  Load ProductionBatch records for a list of batch codes.
  Returns a map of `%{batch_code => %ProductionBatch{}}`.
  """
  def batch_statuses_for_codes([], _actor), do: %{}

  def batch_statuses_for_codes(batch_codes, actor) do
    ProductionBatch
    |> Ash.Query.filter(batch_code in ^batch_codes)
    |> Ash.Query.load([:product])
    |> Ash.read!(actor: actor)
    |> Map.new(fn b -> {b.batch_code, b} end)
  end

  @doc """
  Build a map of `order_item_id -> %{batch_code, batch_id, batch_status}` from allocations.
  This tells us which order items are allocated to which production batches.
  """
  def allocation_map_for_items([], _actor), do: %{}

  def allocation_map_for_items(item_ids, actor) do
    allocations =
      OrderItemBatchAllocation
      |> Ash.Query.filter(order_item_id in ^item_ids)
      |> Ash.Query.load([:production_batch])
      |> Ash.read!(actor: actor)

    Map.new(allocations, fn a ->
      batch = a.production_batch

      {a.order_item_id,
       %{
         batch_code: batch.batch_code,
         batch_id: batch.id,
         batch_status: batch.status
       }}
    end)
  end

  # helpers
  defp total_quantity(items) do
    Enum.reduce(items, D.new(0), fn item, acc -> D.add(acc, item.quantity) end)
  end
end
