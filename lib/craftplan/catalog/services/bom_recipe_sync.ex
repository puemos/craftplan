defmodule Craftplan.Catalog.Services.BOMRecipeSync do
  @moduledoc false

  alias Ash.NotLoaded
  alias Craftplan.Catalog
  alias Craftplan.Catalog.BOM

  @load_paths [components: [:material, :product], labor_steps: []]

  @spec load_bom_for_product(Craftplan.Catalog.Product.t(), keyword) :: BOM.t()
  def load_bom_for_product(product, opts \\ []) do
    actor = Keyword.get(opts, :actor)
    authorize? = Keyword.get(opts, :authorize?, false)

    product
    |> ensure_active_bom(actor, authorize?)
    |> ensure_loaded(actor, authorize?)
  end

  defp ensure_active_bom(product, actor, authorize?) do
    case Map.get(product, :active_bom) do
      %NotLoaded{} ->
        fetch_active_bom(product, actor, authorize?)

      nil ->
        fetch_active_bom(product, actor, authorize?)

      bom ->
        bom
    end
  end

  defp fetch_active_bom(product, actor, authorize?) do
    case Catalog.get_active_bom_for_product(%{product_id: product.id},
           actor: actor,
           authorize?: authorize?
         ) do
      {:ok, %BOM{} = bom} ->
        bom

      _ ->
        # Fallback to latest BOM by version if no active exists
        case Catalog.list_boms_for_product(%{product_id: product.id},
               actor: actor,
               authorize?: authorize?
             ) do
          {:ok, [latest | _]} -> latest
          _ -> new_bom(product)
        end
    end
  end

  defp new_bom(product) do
    %BOM{
      product_id: product.id,
      status: :draft,
      components: [],
      labor_steps: []
    }
  end

  defp ensure_loaded(%BOM{id: nil} = bom, _actor, _authorize?), do: bom

  defp ensure_loaded(%BOM{} = bom, actor, authorize?) do
    Ash.load!(bom, @load_paths,
      actor: actor,
      authorize?: authorize?
    )
  end

  # No recipe population/sync (BOM-only)
end
