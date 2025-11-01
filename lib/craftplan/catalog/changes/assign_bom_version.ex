defmodule Craftplan.Catalog.Changes.AssignBOMVersion do
  @moduledoc false

  use Ash.Resource.Change

  alias Ash.Changeset
  alias Ash.Query
  alias Craftplan.Catalog.BOM

  @impl true
  def change(changeset, _opts, _context) do
    case Changeset.get_attribute(changeset, :product_id) do
      nil ->
        changeset

      product_id ->
        maybe_assign_version(changeset, product_id)
    end
  end

  defp maybe_assign_version(changeset, product_id) do
    case Changeset.get_attribute(changeset, :version) do
      nil ->
        actor = changeset.context[:actor]

        next_version =
          product_id
          |> latest_version(actor)
          |> case do
            nil -> 1
            version -> version + 1
          end

        Changeset.force_change_attribute(changeset, :version, next_version)

      _version ->
        changeset
    end
  end

  defp latest_version(product_id, actor) do
    BOM
    |> Query.new()
    |> Query.filter(product_id == ^product_id)
    |> Query.sort(version: :desc)
    |> Query.limit(1)
    |> Ash.read_one(actor: actor, authorize?: false)
    |> case do
      {:ok, nil} -> nil
      {:ok, %{version: version}} -> version
      {:error, _reason} -> nil
    end
  end
end
