defmodule Craftplan.Orders.Changes.BatchComplete do
  @moduledoc false
  use Ash.Resource.Change

  alias Ash.Changeset
  alias Craftplan.Production.Batching

  @impl true
  def change(changeset, _opts, _ctx) do
    produced_qty = Changeset.get_argument(changeset, :produced_qty)
    duration_minutes = Changeset.get_argument(changeset, :duration_minutes)
    completed_map = Changeset.get_argument(changeset, :completed_map)

    changeset
    |> Changeset.force_change_attribute(:status, :completed)
    |> Changeset.force_change_attribute(:produced_qty, produced_qty)
    |> Changeset.force_change_attribute(:completed_at, DateTime.utc_now())
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
