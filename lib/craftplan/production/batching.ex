defmodule Craftplan.Production.Batching do
  @moduledoc """
  Service layer for batch-centric production actions: open, start, consume, complete.
  """

  import Ash.Expr

  alias Ash.Changeset
  alias Craftplan.Catalog
  alias Craftplan.Catalog.Services.BatchCostCalculator
  alias Craftplan.Inventory
  alias Craftplan.Inventory.Lot
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
    |> Changeset.for_update(:start, %{})
    |> Ash.update(actor: actor)
  end

  @doc """
  Auto-selects lots using FIFO (earliest expiry first) for all materials in a batch.
  Returns {:ok, lot_plan} or {:error, {:insufficient_stock, material_id, required, short}}.
  """
  def auto_select_lots(%ProductionBatch{} = batch, produced_qty) do
    components_map = batch.components_map || %{}
    produced_qty = normalize(produced_qty)

    Enum.reduce_while(components_map, {:ok, %{}}, fn {material_id, per_unit_str}, {:ok, acc} ->
      required = D.mult(D.new(per_unit_str), produced_qty)

      lots =
        Lot
        |> Ash.Query.filter(material_id == ^material_id and current_stock > 0)
        |> Ash.Query.load([:current_stock])
        |> Ash.Query.sort(expiry_date: :asc)
        |> Ash.read!(authorize?: false)

      case allocate_from_lots(lots, required) do
        {:ok, entries} -> {:cont, {:ok, Map.put(acc, material_id, entries)}}
        {:error, short} -> {:halt, {:error, {:insufficient_stock, material_id, required, short}}}
      end
    end)
  end

  defp allocate_from_lots(lots, required) do
    {entries, remaining} =
      Enum.reduce_while(lots, {[], required}, fn lot, {acc, remaining} ->
        if D.lte?(remaining, D.new(0)) do
          {:halt, {acc, remaining}}
        else
          take = D.min(lot.current_stock, remaining)
          entry = %{lot_id: lot.id, quantity: take}
          {:cont, {[entry | acc], D.sub(remaining, take)}}
        end
      end)

    if D.gt?(remaining, D.new(0)) do
      {:error, remaining}
    else
      {:ok, Enum.reverse(entries)}
    end
  end

  @doc """
  Records consumption plan and writes stock movements + ProductionBatchLot entries.

  lot_plan: %{material_id => [%{lot_id: ..., quantity: ...}]}
  """
  def consume_batch(%ProductionBatch{} = batch, lot_plan, opts \\ []) when is_map(lot_plan) do
    actor = Keyword.get(opts, :actor)
    output_qty = Keyword.get(opts, :expected_output_qty, batch.planned_qty)

    with false <- batch_consumed?(batch, actor),
         {:ok, normalized_plan} <- validate_lot_plan(batch, lot_plan, output_qty, actor) do
      normalized_plan
      |> Enum.flat_map(fn {_material_id, entries} -> entries end)
      |> Enum.reduce_while({:ok, :consumed}, fn %{lot: lot, quantity: qty}, _acc ->
        with {:ok, _batch_lot} <-
               ProductionBatchLot
               |> Changeset.for_create(:create, %{
                 production_batch_id: batch.id,
                 lot_id: lot.id,
                 quantity_used: qty
               })
               |> Ash.create(actor: actor),
             {:ok, _movement} <-
               Inventory.Movement
               |> Changeset.for_create(:adjust_stock, %{
                 material_id: lot.material_id,
                 lot_id: lot.id,
                 quantity: D.negate(qty),
                 reason: "Batch #{batch.batch_code} consumption"
               })
               |> Ash.create(actor: actor) do
          {:cont, {:ok, :consumed}}
        else
          {:error, reason} -> {:halt, {:error, reason}}
        end
      end)
    else
      true -> {:error, :already_consumed}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Validates and normalizes a manual material lot plan against the frozen batch recipe.
  """
  def validate_lot_plan(%ProductionBatch{} = batch, lot_plan, output_qty, actor) do
    expected = expected_material_quantities(batch, output_qty)

    with :ok <- validate_material_keys(expected, lot_plan),
         {:ok, normalized_plan} <- load_and_validate_lots(lot_plan, actor),
         :ok <- validate_plan_totals(expected, normalized_plan),
         :ok <- validate_available_stock(normalized_plan) do
      {:ok, normalized_plan}
    end
  end

  def batch_consumed?(%ProductionBatch{} = batch, actor) do
    ProductionBatchLot
    |> Ash.Query.filter(production_batch_id == ^batch.id)
    |> Ash.Query.limit(1)
    |> Ash.exists?(actor: actor)
    |> case do
      {:ok, exists?} -> exists?
      _ -> false
    end
  end

  def validate_recorded_consumption(%ProductionBatch{} = batch, output_qty, actor) do
    expected = expected_material_quantities(batch, output_qty)

    plan =
      ProductionBatchLot
      |> Ash.Query.filter(production_batch_id == ^batch.id)
      |> Ash.Query.load(lot: [:current_stock])
      |> Ash.read!(actor: actor)
      |> Enum.group_by(& &1.lot.material_id)
      |> Map.new(fn {material_id, usages} ->
        entries = Enum.map(usages, &%{lot: &1.lot, quantity: &1.quantity_used})
        {material_id, entries}
      end)

    with :ok <- validate_material_keys(expected, plan) do
      validate_plan_totals(expected, plan)
    end
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

          %{allocation: a, completed_qty: target}
        end)

      completed_total =
        Enum.reduce(completed_allocs, D.new(0), fn completed, acc ->
          D.add(acc, completed.completed_qty)
        end)

      valid_completion? =
        D.gt?(produced_qty, D.new(0)) and
          D.equal?(completed_total, produced_qty) and
          Enum.all?(completed_allocs, fn completed ->
            D.lte?(completed.completed_qty, completed.allocation.planned_qty)
          end)

      if valid_completion? do
        complete_allocations(batch, completed_allocs, completed_total, produced_qty, actor)
      else
        {:error, :invalid_completed_quantities}
      end
    end
  end

  defp complete_allocations(batch, completed_allocs, completed_total, produced_qty, actor) do
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
    Enum.each(completed_allocs, fn completed ->
      a = completed.allocation

      ratio =
        if D.compare(completed_total, D.new(0)) == :gt,
          do: D.div(completed.completed_qty, completed_total),
          else: D.new(0)

      item =
        Orders.get_order_item_by_id!(a.order_item_id, actor: actor, load: [:quantity, :status])

      inc_material = D.mult(costs.material_cost, ratio)
      inc_labor = D.mult(costs.labor_cost, ratio)
      inc_overhead = D.mult(costs.overhead_cost, ratio)

      # Persist the allocation before deriving the item's aggregate completion state.
      _ =
        a
        |> Changeset.for_update(:update, %{completed_qty: completed.completed_qty})
        |> Ash.update!(actor: actor)

      _ =
        item
        |> Changeset.for_update(:update, %{
          status: new_item_status(item, actor),
          material_cost: D.add(item.material_cost || D.new(0), inc_material),
          labor_cost: D.add(item.labor_cost || D.new(0), inc_labor),
          overhead_cost: D.add(item.overhead_cost || D.new(0), inc_overhead),
          unit_cost: costs.unit_cost
        })
        |> Ash.update!(actor: actor)
    end)

    # Split batch lot usage proportionally to items
    batch_lots =
      ProductionBatchLot
      |> Ash.Query.filter(expr(production_batch_id == ^batch.id))
      |> Ash.read!(actor: actor)

    Enum.each(batch_lots, fn bl ->
      Enum.each(completed_allocs, fn completed ->
        a = completed.allocation

        ratio =
          if D.compare(completed_total, D.new(0)) == :gt,
            do: D.div(completed.completed_qty, completed_total),
            else: D.new(0)

        qty_used = D.mult(bl.quantity_used || D.new(0), ratio)

        if D.compare(qty_used, D.new(0)) == :gt do
          OrderItemLot
          |> Changeset.for_create(:create, %{
            order_item_id: a.order_item_id,
            order_item_batch_allocation_id: a.id,
            lot_id: bl.lot_id,
            quantity_used: qty_used
          })
          |> Ash.create!(actor: actor)
        end
      end)
    end)

    {:ok, :completed}
  end

  defp new_item_status(item, actor) do
    qty = item.quantity || D.new(0)

    completed_qty =
      OrderItemBatchAllocation
      |> Ash.Query.filter(order_item_id == ^item.id)
      |> Ash.Query.select([:completed_qty])
      |> Ash.read!(actor: actor)
      |> Enum.reduce(D.new(0), &D.add(&2, &1.completed_qty || D.new(0)))

    cond do
      D.equal?(completed_qty, D.new(0)) -> item.status
      D.lt?(completed_qty, qty) -> :in_progress
      true -> :done
    end
  end

  defp expected_material_quantities(batch, output_qty) do
    output_qty = normalize(output_qty)

    Map.new(batch.components_map || %{}, fn {material_id, per_unit} ->
      {to_string(material_id), D.mult(normalize(per_unit), output_qty)}
    end)
  end

  defp validate_material_keys(expected, plan) do
    expected_keys = expected |> Map.keys() |> MapSet.new()
    actual_keys = plan |> Map.keys() |> MapSet.new(&to_string/1)

    if MapSet.equal?(expected_keys, actual_keys) do
      :ok
    else
      {:error, {:lot_plan_materials_mismatch, MapSet.to_list(expected_keys), MapSet.to_list(actual_keys)}}
    end
  end

  defp load_and_validate_lots(lot_plan, actor) do
    Enum.reduce_while(lot_plan, {:ok, %{}}, fn {material_id, entries}, {:ok, acc} ->
      material_id = to_string(material_id)

      result =
        Enum.reduce_while(entries, {:ok, []}, fn entry, {:ok, loaded} ->
          lot_id = Map.get(entry, :lot_id) || Map.get(entry, "lot_id")
          qty = normalize(Map.get(entry, :quantity) || Map.get(entry, "quantity"))

          if D.gt?(qty, D.new(0)) do
            case Ash.get(Lot, lot_id,
                   actor: actor,
                   authorize?: false,
                   load: [:current_stock]
                 ) do
              {:ok, %{material_id: lot_material_id} = lot} ->
                if to_string(lot_material_id) == material_id do
                  {:cont, {:ok, [%{lot: lot, quantity: qty} | loaded]}}
                else
                  {:halt, {:error, {:lot_material_mismatch, lot_id, material_id}}}
                end

              {:error, reason} ->
                {:halt, {:error, reason}}
            end
          else
            {:halt, {:error, {:invalid_lot_quantity, lot_id}}}
          end
        end)

      case result do
        {:ok, loaded} -> {:cont, {:ok, Map.put(acc, material_id, Enum.reverse(loaded))}}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
  end

  defp validate_plan_totals(expected, plan) do
    Enum.reduce_while(expected, :ok, fn {material_id, required}, :ok ->
      total =
        plan
        |> Map.get(material_id, [])
        |> Enum.reduce(D.new(0), fn entry, acc -> D.add(acc, entry.quantity) end)

      if D.equal?(required, total) do
        {:cont, :ok}
      else
        {:halt, {:error, {:lot_plan_quantity_mismatch, material_id, required, total}}}
      end
    end)
  end

  defp validate_available_stock(plan) do
    plan
    |> Enum.flat_map(fn {_material_id, entries} -> entries end)
    |> Enum.group_by(& &1.lot.id)
    |> Enum.reduce_while(:ok, fn {lot_id, entries}, :ok ->
      requested = Enum.reduce(entries, D.new(0), &D.add(&2, &1.quantity))
      available = entries |> hd() |> Map.fetch!(:lot) |> Map.get(:current_stock) || D.new(0)

      if D.lte?(requested, available) do
        {:cont, :ok}
      else
        {:halt, {:error, {:insufficient_lot_stock, lot_id, requested, available}}}
      end
    end)
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
