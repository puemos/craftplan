defmodule Craftplan.Orders.Changes.BatchComplete do
  @moduledoc false
  use Ash.Resource.Change

  alias Ash.Changeset
  alias Craftplan.Production.Batching
  alias Decimal, as: D

  @impl true
  def change(changeset, _opts, _ctx) do
    produced_qty = Changeset.get_argument(changeset, :produced_qty)
    duration_minutes = Changeset.get_argument(changeset, :duration_minutes)
    completed_map = Changeset.get_argument(changeset, :completed_map)
    lot_plan = Changeset.get_argument(changeset, :lot_plan)

    changeset
    |> Changeset.force_change_attribute(:status, :completed)
    |> Changeset.force_change_attribute(:produced_qty, produced_qty)
    |> Changeset.force_change_attribute(:completed_at, DateTime.utc_now())
    |> Changeset.before_action(fn changeset ->
      batch = changeset.data
      actor = changeset.context[:private][:actor]

      resolved_plan =
        if lot_plan && map_size(lot_plan) > 0 do
          {:ok, lot_plan}
        else
          Batching.auto_select_lots(batch, produced_qty)
        end

      case resolved_plan do
        {:ok, plan} ->
          if map_size(plan) > 0 do
            {:ok, _} = Batching.consume_batch(batch, plan, actor: actor)
          end

          changeset

        {:error, {:insufficient_stock, material_id, required, short}} ->
          Changeset.add_error(changeset,
            field: :lot_plan,
            message: "Insufficient stock for material %{material_id}. Need %{required}, short by %{short}.",
            vars: %{
              material_id: material_id,
              required: D.to_string(required),
              short: D.to_string(short)
            }
          )
      end
    end)
    |> Changeset.after_action(fn changeset, batch ->
      actor = changeset.context[:private][:actor]

      case Batching.complete_batch(batch,
             actor: actor,
             produced_qty: produced_qty,
             duration_minutes: duration_minutes,
             completed_map: completed_map
           ) do
        {:ok, _} -> {:ok, batch}
        {:error, reason} -> {:error, reason}
      end
    end)
  end
end
