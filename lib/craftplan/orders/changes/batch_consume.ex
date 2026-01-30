defmodule Craftplan.Orders.Changes.BatchConsume do
  @moduledoc false
  use Ash.Resource.Change

  alias Ash.Changeset
  alias Craftplan.Production.Batching

  @impl true
  def change(changeset, _opts, _ctx) do
    batch = changeset.data

    Changeset.before_action(changeset, fn changeset ->
      actor = changeset.context[:private][:actor]
      lot_plan = Changeset.get_argument(changeset, :lot_plan) || %{}

      case Batching.consume_batch(batch, lot_plan, actor: actor) do
        {:ok, _} -> changeset
      end
    end)
  end
end
