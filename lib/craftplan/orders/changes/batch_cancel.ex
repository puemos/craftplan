defmodule Craftplan.Orders.Changes.BatchCancel do
  @moduledoc false
  use Ash.Resource.Change

  alias Ash.Changeset
  alias Craftplan.Production.Batching

  @impl true
  def change(changeset, _opts, context) do
    changeset
    |> Changeset.before_action(fn changeset ->
      actor = context.actor

      if Batching.batch_consumed?(changeset.data, actor) do
        Changeset.add_error(changeset,
          field: :status,
          message: "A batch with recorded material consumption cannot be canceled."
        )
      else
        changeset
      end
    end)
    |> Changeset.manage_relationship(:allocations, [], type: :direct_control)
  end
end
