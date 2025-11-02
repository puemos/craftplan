defmodule Craftplan.Catalog.Changes.AssignBOMVersion do
  @moduledoc false

  use Ash.Resource.Change

  alias Ash.Changeset
  alias Ash.Query
  alias Craftplan.Catalog.BOM

  @impl true
  def change(changeset, _opts, _context) do
    case Changeset.get_attribute(changeset, :product_id) do
      product_id when not is_nil(product_id) -> maybe_assign_version(changeset, product_id)
      _ -> changeset
    end
  end

  defp maybe_assign_version(changeset, product_id) do
    with nil <- Changeset.get_attribute(changeset, :version),
         {:ok, next_version} <- compute_next_version(product_id, changeset.context[:actor]) do
      Changeset.force_change_attribute(changeset, :version, next_version)
    else
      _ -> changeset
    end
  end

  defp compute_next_version(product_id, actor) do
    case latest_version(product_id, actor) do
      {:ok, version} -> {:ok, version + 1}
      :not_found -> {:ok, 1}
      {:error, reason} -> {:error, reason}
    end
  end

  defp latest_version(product_id, actor) do
    case BOM
         |> Query.new()
         |> Query.filter(product_id == ^product_id)
         |> Query.sort(version: :desc)
         |> Query.limit(1)
         |> Ash.read_one(actor: actor, authorize?: false) do
      {:ok, %{version: version}} -> {:ok, version}
      {:ok, nil} -> :not_found
      {:error, reason} -> {:error, reason}
    end
  end
end
