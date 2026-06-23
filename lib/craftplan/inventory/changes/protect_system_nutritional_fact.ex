defmodule Craftplan.Inventory.Changes.ProtectSystemNutritionalFact do
  @moduledoc false

  use Ash.Resource.Change

  alias Ash.Changeset

  @impl true
  def change(changeset, _opts, _context) do
    if Map.get(changeset.data, :system) do
      Changeset.add_error(changeset,
        field: :system,
        message: "system nutritional facts cannot be deleted"
      )
    else
      changeset
    end
  end
end
