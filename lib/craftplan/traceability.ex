defmodule Craftplan.Traceability do
  @moduledoc """
  Builds bidirectional ingredient-lot and finished-batch traceability reports.

  The reports deliberately use the frozen production batch links rather than the
  current product recipe, so they remain useful after recipes change.
  """

  alias Craftplan.Inventory.Lot
  alias Craftplan.Orders
  alias Craftplan.Orders.ProductionBatchLot
  alias Craftplan.Production
  alias Decimal, as: D

  require Ash.Query

  def lookup(query, opts \\ []) do
    actor = Keyword.get(opts, :actor)
    mode = Keyword.get(opts, :mode, :both)
    query = query |> to_string() |> String.trim()

    if query == "" do
      %{query: query, lots: [], batches: []}
    else
      %{
        query: query,
        lots:
          if(mode in [:forward, :recall, :both],
            do: ingredient_lot_reports(query, actor),
            else: []
          ),
        batches:
          if(mode in [:backward, :recall, :both],
            do: finished_batch_reports(query, actor),
            else: []
          )
      }
    end
  end

  def recent_lots(opts \\ []) do
    actor = Keyword.get(opts, :actor)
    limit = Keyword.get(opts, :limit, 6)

    Lot
    |> Ash.Query.sort(received_at: :desc)
    |> Ash.Query.limit(limit)
    |> Ash.Query.load([
      :current_stock,
      :received_quantity,
      :status,
      material: [:name, :unit],
      supplier: [:name]
    ])
    |> Ash.read!(actor: actor)
  rescue
    _ -> []
  end

  defp ingredient_lot_reports(query, actor) do
    upper_query = String.upcase(query)

    lots =
      Lot
      |> Ash.Query.filter(
        lot_code == ^query or lot_code == ^upper_query or supplier_lot_code == ^query or
          supplier_lot_code == ^upper_query
      )
      |> Ash.Query.load([
        :current_stock,
        :received_quantity,
        :status,
        :expiry_date,
        material: [:name, :sku, :unit],
        supplier: [:name, :address],
        purchase_order_item: [purchase_order: [:reference, :received_at]]
      ])
      |> Ash.read!(actor: actor)

    usages_by_lot = lot_usages(lots, actor)

    Enum.map(lots, fn lot ->
      %{
        lot: lot,
        source: source_details(lot),
        batches: Map.get(usages_by_lot, lot.id, [])
      }
    end)
  end

  defp lot_usages([], _actor), do: %{}

  defp lot_usages(lots, actor) do
    lot_ids = Enum.map(lots, & &1.id)

    ProductionBatchLot
    |> Ash.Query.filter(lot_id in ^lot_ids)
    |> Ash.Query.load(
      production_batch: [
        :batch_code,
        :status,
        :produced_qty,
        :completed_at,
        product: [:name, :sku],
        allocations: [
          :planned_qty,
          :completed_qty,
          order_item: [
            order: [
              :reference,
              :delivery_date,
              customer: [:full_name, :email, :phone, :shipping_address]
            ]
          ]
        ]
      ]
    )
    |> Ash.read!(actor: actor)
    |> Enum.group_by(& &1.lot_id)
    |> Map.new(fn {lot_id, usages} ->
      reports =
        Enum.map(usages, fn usage ->
          batch = usage.production_batch

          %{
            batch: batch,
            quantity_used: usage.quantity_used,
            orders: Enum.map(batch.allocations, &order_destination/1)
          }
        end)

      {lot_id, reports}
    end)
  end

  defp finished_batch_reports(query, actor) do
    case find_batch(query, actor) do
      {:ok, nil} ->
        []

      {:ok, batch} ->
        report = Production.batch_report!(batch.batch_code, actor: actor)

        [
          %{
            batch: report.production_batch,
            product: report.product,
            produced_at: report.produced_at,
            lots: enrich_batch_lots(report.lots, actor),
            orders: report.orders
          }
        ]

      {:error, _reason} ->
        []
    end
  end

  defp find_batch(query, actor) do
    case Orders.get_production_batch_by_code(%{batch_code: query}, actor: actor) do
      {:ok, nil} ->
        upper_query = String.upcase(query)

        if query == upper_query do
          {:ok, nil}
        else
          Orders.get_production_batch_by_code(%{batch_code: upper_query}, actor: actor)
        end

      result ->
        result
    end
  end

  defp enrich_batch_lots(lots, actor) do
    lot_ids = Enum.map(lots, & &1.lot.id)

    enriched_by_id =
      case lot_ids do
        [] ->
          %{}

        ids ->
          Lot
          |> Ash.Query.filter(id in ^ids)
          |> Ash.Query.load(
            material: [:name, :sku, :unit],
            supplier: [:name, :address],
            purchase_order_item: [purchase_order: [:reference, :received_at]]
          )
          |> Ash.read!(actor: actor)
          |> Map.new(&{&1.id, &1})
      end

    Enum.map(lots, fn usage ->
      lot = Map.get(enriched_by_id, usage.lot.id, usage.lot)
      usage |> Map.put(:lot, lot) |> Map.put(:source, source_details(lot))
    end)
  end

  defp source_details(lot) do
    po = lot.purchase_order_item && lot.purchase_order_item.purchase_order

    %{
      supplier: lot.supplier,
      purchase_order_reference: po && po.reference,
      received_at: (po && po.received_at) || lot.received_at
    }
  end

  defp order_destination(allocation) do
    order = allocation.order_item.order
    customer = order.customer

    %{
      reference: order.reference,
      delivery_date: order.delivery_date,
      quantity: allocation_quantity(allocation),
      customer_name: customer && customer.full_name,
      customer_email: customer && customer.email,
      customer_phone: customer && customer.phone,
      shipping_address: customer && customer.shipping_address
    }
  end

  defp allocation_quantity(allocation) do
    if D.gt?(allocation.completed_qty || D.new(0), D.new(0)),
      do: allocation.completed_qty,
      else: allocation.planned_qty || D.new(0)
  end
end
