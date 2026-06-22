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
    Changeset.after_action(changeset, fn cs, result ->
      cond do
        bypass?(cs) -> {:ok, result}
        price_changed?(cs) -> refresh_and_return(result, cs.context[:actor])
        true -> {:ok, result}
      end
    end)
  end

  defp price_changed?(changeset) do
    Changeset.changing_attribute?(changeset, :price)
  end

  # Callers that update many materials in a tight loop (PO receive, backfill)
  # can set context.bypass_bom_refresh? to true to defer the refresh and run
  # one bulk pass at the end instead of N individual ones.
  defp bypass?(changeset) do
    changeset.context[:bypass_bom_refresh?] == true
  end

  defp refresh_and_return(result, actor) do
    refresh_affected_rollups(result.id, actor)
    {:ok, result}
  end

  @doc """
  Refresh all BOM rollups affected by a single material, outside the context
  of a Material changeset. Used by callers (e.g. PO.receive) that update
  multiple materials with the rollup refresh bypassed, then run one bulk
  refresh per unique material at the end.
  """
  def refresh_for_material!(material_id, actor \\ nil) do
    refresh_affected_rollups(material_id, actor)
    :ok
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
