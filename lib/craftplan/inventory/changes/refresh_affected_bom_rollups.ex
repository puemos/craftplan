defmodule Craftplan.Inventory.Changes.RefreshAffectedBomRollups do
  @moduledoc """
  After a Material update, if the price changed, refresh all BOM Rollups
  that use this material so persisted cost data stays in sync.
  """

  use Ash.Resource.Change

  import Ash.Expr

  alias Ash.Changeset
  alias Craftplan.Catalog.BOMComponent
  alias Craftplan.Catalog.Services.BOMRollup

  require Ash.Query

  @impl true
  def change(changeset, _opts, _context) do
    Changeset.after_action(changeset, fn _changeset, result ->
      if price_changed?(changeset) do
        refresh_affected_rollups(result.id, changeset.context[:actor])
      end

      {:ok, result}
    end)
  end

  defp price_changed?(changeset) do
    Changeset.changing_attribute?(changeset, :price)
  end

  defp refresh_affected_rollups(material_id, actor) do
    material_id
    |> find_affected_bom_ids(actor)
    |> Enum.each(fn bom_id ->
      BOMRollup.refresh_by_bom_id!(bom_id, actor: actor, authorize?: false)
    end)
  end

  defp find_affected_bom_ids(material_id, actor) do
    BOMComponent
    |> Ash.Query.new()
    |> Ash.Query.filter(expr(material_id == ^material_id))
    |> Ash.Query.select([:bom_id])
    |> Ash.read!(actor: actor, authorize?: false)
    |> Enum.map(& &1.bom_id)
    |> Enum.uniq()
  end
end
