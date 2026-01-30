defmodule Craftplan.Production.Batching do
  @moduledoc """
  Service layer for batch-centric production actions: open, start, consume, complete.
  """

  import Ash.Expr

  alias Ash.Changeset
  alias Craftplan.Catalog
  alias Craftplan.Catalog.Services.BatchCostCalculator
  alias Craftplan.Inventory
  alias Craftplan.Orders
  alias Craftplan.Orders.OrderItemBatchAllocation
  alias Craftplan.Orders.OrderItemLot
  alias Craftplan.Orders.ProductionBatch
  alias Craftplan.Orders.ProductionBatchLot
  alias Decimal, as: D

  require Ash.Query

  @doc """
  Opens a new batch for a product with a frozen BOM snapshot and planned quantity.

  Returns {:ok, %ProductionBatch{}} or {:error, reason}.
  """
  def open_batch(product_id, planned_qty, opts \\ []) do
    actor = Keyword.get(opts, :actor)
    notes = Keyword.get(opts, :notes)

    product =
      Catalog.get_product_by_id!(product_id,
        load: [active_bom: [:rollup, components: []]],
        actor: actor
      )

    {_bom, _bom_version, _components_map} =
      case product.active_bom do
        nil ->
          {nil, nil, %{}}

        bom ->
          version = Map.get(bom, :version)
          cmap = (bom.rollup && Map.get(bom.rollup, :components_map)) || %{}
          {bom, version, cmap}
      end

    _code = generate_batch_code(product.sku, actor)

    params = %{
      product_id: product.id,
      planned_qty: normalize(planned_qty),
      notes: notes
    }

    ProductionBatch
    |> Changeset.for_create(:open, params)
    |> Ash.create(actor: actor)
  end

  def generate_batch_code(sku, actor) do
    date = Calendar.strftime(Date.utc_today(), "%Y%m%d")
    prefix = "B-#{date}-#{sku}"

    {:ok, latest} =
      ProductionBatch
      |> Ash.Query.new()
      |> Ash.Query.filter(expr(fragment("? LIKE ?", batch_code, ^"#{prefix}-%")))
      |> Ash.Query.sort(batch_code: :desc)
      |> Ash.read_one(actor: actor, authorize?: false)

    next =
      case latest do
        nil ->
          1

        %{batch_code: code} ->
          code |> String.split("-") |> List.last() |> to_int(0) |> Kernel.+(1)
      end

    "#{prefix}-#{String.pad_leading(Integer.to_string(next), 3, "0")}"
  end

  @doc """
  Starts a batch (status → :in_progress).
  """
  def start_batch(%ProductionBatch{} = batch, opts \\ []) do
    actor = Keyword.get(opts, :actor)

    batch
    |> Changeset.for_update(:update, %{status: :in_progress, started_at: DateTime.utc_now()})
    |> Ash.update(actor: actor)
  end

  @doc """
  Records consumption plan and writes stock movements + ProductionBatchLot entries.

  lot_plan: %{material_id => [%{lot_id: ..., quantity: ...}]}
  """
  def consume_batch(%ProductionBatch{} = batch, lot_plan, opts \\ []) when is_map(lot_plan) do
    actor = Keyword.get(opts, :actor)

    Enum.each(lot_plan, fn {_material_id, entries} ->
      Enum.each(entries, fn %{lot_id: lot_id, quantity: qty} ->
        # Record batch → lot usage
        ProductionBatchLot
        |> Changeset.for_create(:create, %{
          production_batch_id: batch.id,
          lot_id: lot_id,
          quantity_used: normalize(qty)
        })
        |> Ash.create!(actor: actor)

        # Adjust stock (negative)
        Inventory.Movement
        |> Changeset.for_create(:adjust_stock, %{
          material_id: get_lot_material_id(lot_id, actor),
          lot_id: lot_id,
          quantity: D.mult(normalize(qty), D.new(-1)),
          reason: "Batch #{batch.batch_code} consumption"
        })
        |> Ash.create!(actor: actor)
      end)
    end)

    {:ok, :consumed}
  end

  defp get_lot_material_id(lot_id, actor) do
    Craftplan.Inventory.Lot
    |> Ash.get!(lot_id, actor: actor, authorize?: false)
    |> Map.fetch!(:material_id)
  end

  @doc """
  Completes a batch: compute costs, allocate to items, update item statuses, and split lot usage to items.

  Options:
  - :produced_qty (required)
  - :duration_minutes
  - :overhead_percent (optional; fallback to settings)
  - :completed_map (optional map of order_item_id => completed_qty); defaults to scaled planned_qty
  """
  def complete_batch(%ProductionBatch{} = batch, opts) do
    actor = Keyword.fetch!(opts, :actor)
    produced_qty = opts |> Keyword.fetch!(:produced_qty) |> normalize()
    _duration_minutes = opts |> Keyword.get(:duration_minutes, 0) |> normalize()

    batch = Ash.reload!(batch, actor: actor)

    # Load allocations
    allocations =
      OrderItemBatchAllocation
      |> Ash.Query.filter(expr(production_batch_id == ^batch.id))
      |> Ash.read!(actor: actor)

    if Enum.empty?(allocations) do
      {:error, :no_allocations}
    else
      completed_map = Keyword.get(opts, :completed_map)

      planned_total =
        Enum.reduce(allocations, D.new(0), fn a, acc -> D.add(acc, a.planned_qty || D.new(0)) end)

      completed_allocs =
        Enum.map(allocations, fn a ->
          target =
            case completed_map && Map.get(completed_map, a.order_item_id) do
              nil ->
                if D.compare(planned_total, D.new(0)) == :gt do
                  # scale proportionally to produced
                  D.mult(produced_qty, D.div(a.planned_qty || D.new(0), planned_total))
                else
                  D.new(0)
                end

              qty ->
                normalize(qty)
            end

          %{a | completed_qty: target}
        end)

      completed_total =
        Enum.reduce(completed_allocs, D.new(0), fn a, acc -> D.add(acc, a.completed_qty) end)

      # Compute batch costs using BOM snapshot
      bom = batch.bom_id && Ash.get!(Catalog.BOM, batch.bom_id, actor: actor, authorize?: false)

      costs =
        if bom do
          BatchCostCalculator.calculate(bom, produced_qty, actor: actor, authorize?: false)
        else
          %{
            material_cost: D.new(0),
            labor_cost: D.new(0),
            overhead_cost: D.new(0),
            unit_cost: D.new(0)
          }
        end

      # Update each allocation + order item
      Enum.each(completed_allocs, fn a ->
        ratio =
          if D.compare(completed_total, D.new(0)) == :gt,
            do: D.div(a.completed_qty, completed_total),
            else: D.new(0)

        item =
          Orders.get_order_item_by_id!(a.order_item_id, actor: actor, load: [:quantity, :status])

        inc_material = D.mult(costs.material_cost, ratio)
        inc_labor = D.mult(costs.labor_cost, ratio)
        inc_overhead = D.mult(costs.overhead_cost, ratio)

        _ =
          item
          |> Changeset.for_update(:update, %{
            status: new_item_status(item, a.completed_qty),
            material_cost: D.add(item.material_cost || D.new(0), inc_material),
            labor_cost: D.add(item.labor_cost || D.new(0), inc_labor),
            overhead_cost: D.add(item.overhead_cost || D.new(0), inc_overhead),
            unit_cost: costs.unit_cost
          })
          |> Ash.update!(actor: actor)

        # Persist allocation completed_qty
        _ =
          a
          |> Changeset.for_update(:update, %{completed_qty: a.completed_qty})
          |> Ash.update!(actor: actor)
      end)

      # Split batch lot usage proportionally to items
      batch_lots =
        ProductionBatchLot
        |> Ash.Query.filter(expr(production_batch_id == ^batch.id))
        |> Ash.read!(actor: actor)

      Enum.each(batch_lots, fn bl ->
        Enum.each(completed_allocs, fn a ->
          ratio =
            if D.compare(completed_total, D.new(0)) == :gt,
              do: D.div(a.completed_qty, completed_total),
              else: D.new(0)

          qty_used = D.mult(bl.quantity_used || D.new(0), ratio)

          if D.compare(qty_used, D.new(0)) == :gt do
            OrderItemLot
            |> Changeset.for_create(:create, %{
              order_item_id: a.order_item_id,
              lot_id: bl.lot_id,
              quantity_used: qty_used
            })
            |> Ash.create!(actor: actor)
          end
        end)
      end)

      {:ok, :completed}
    end
  end

  defp new_item_status(item, add_completed_qty) do
    qty = item.quantity || D.new(0)

    # naive progression: todo -> in_progress -> done; if you allow multiple completions,
    # you'll sum across allocations with a read; simplified here: if completed reaches qty, done
    cond do
      D.compare(add_completed_qty, D.new(0)) == :eq -> item.status
      D.compare(add_completed_qty, qty) == :lt -> :in_progress
      true -> :done
    end
  end

  defp to_int(str, default) when is_binary(str) do
    case Integer.parse(str) do
      {i, _} -> i
      :error -> default
    end
  end

  defp to_int(_, default), do: default

  defp normalize(nil), do: D.new(0)
  defp normalize(%D{} = d), do: d
  defp normalize(val) when is_integer(val), do: D.new(val)
  defp normalize(val) when is_float(val), do: D.from_float(val)
  defp normalize(val) when is_binary(val), do: D.new(val)
end
