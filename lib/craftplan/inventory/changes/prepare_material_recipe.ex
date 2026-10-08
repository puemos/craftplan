defmodule Craftplan.Inventory.Changes.PrepareMaterialRecipe do
  @moduledoc false
  use Ash.Resource.Change

  alias Ash.Changeset
  alias Craftplan.Inventory.Material
  alias Craftplan.Inventory.MaterialRecipe

  require Ash.Query

  @impl true
  def change(changeset, _opts, _context) do
    Changeset.before_action(changeset, fn changeset ->
      actor = changeset.context[:private][:actor]
      material_id = Changeset.get_attribute(changeset, :material_id)
      # Serialize version allocation for this material.
      Material
      |> Ash.Query.filter(id == ^material_id)
      |> Ash.Query.lock(:for_update)
      |> Ash.read_one!(actor: actor)

      case Craftplan.Inventory.Intermediates.normalize_components(
             Changeset.get_attribute(changeset, :components),
             material_id,
             actor
           ) do
        {:ok, components} ->
          latest =
            MaterialRecipe
            |> Ash.Query.filter(material_id == ^material_id)
            |> Ash.Query.sort(version: :desc)
            |> Ash.Query.limit(1)
            |> Ash.read_one!(actor: actor)

          changeset
          |> Changeset.force_change_attribute(:components, components)
          |> Changeset.force_change_attribute(
            :version,
            if(latest, do: latest.version + 1, else: 1)
          )

        {:error, reason} ->
          Changeset.add_error(changeset, field: :components, message: reason)
      end
    end)
  end
end
