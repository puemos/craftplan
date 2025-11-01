defmodule Craftplan.Catalog.Services.BOMRecipeSync do
  @moduledoc false

  alias Ash.NotLoaded
  alias Craftplan.Catalog
  alias Craftplan.Catalog.BOM
  alias Craftplan.Catalog.BOMComponent
  alias Craftplan.Catalog.Recipe

  @load_paths [components: [:material, :product], labor_steps: []]

  @spec load_bom_for_product(Craftplan.Catalog.Product.t(), keyword) :: BOM.t()
  def load_bom_for_product(product, opts \\ []) do
    actor = Keyword.get(opts, :actor)
    authorize? = Keyword.get(opts, :authorize?, false)

    product
    |> ensure_active_bom(actor, authorize?)
    |> ensure_loaded(actor, authorize?)
    |> populate_from_recipe(product, actor, authorize?)
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
      {:ok, %BOM{} = bom} -> bom
      _ -> new_bom(product)
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

  defp populate_from_recipe(%BOM{id: nil} = bom, product, actor, authorize?) do
    case load_recipe(product, actor, authorize?) do
      recipe when not is_nil(recipe) ->
        components =
          Enum.map(recipe.components, fn component ->
            %BOMComponent{
              component_type: :material,
              material_id: component.material_id,
              material: component.material,
              quantity: component.quantity
            }
          end)

        %{bom | components: components}

      _ ->
        bom
    end
  end

  defp populate_from_recipe(bom, _product, _actor, _authorize?), do: bom

  def sync_recipe_from_bom(product, bom, opts \\ []) do
    actor = Keyword.get(opts, :actor)
    authorize? = Keyword.get(opts, :authorize?, false)

    component_params =
      bom.components
      |> Enum.filter(&(&1.component_type == :material))
      |> Enum.map(fn component ->
        %{
          material_id: component.material_id,
          quantity: component.quantity
        }
      end)

    case load_recipe(product, actor, authorize?) do
      nil ->
        create_recipe(product.id, component_params, actor, authorize?)

      %Recipe{} = recipe ->
        update_recipe(recipe, component_params, actor, authorize?)
    end
  end

  defp create_recipe(_product_id, [], _actor, _authorize?), do: :ok

  defp create_recipe(product_id, components, actor, authorize?) do
    Recipe
    |> Ash.Changeset.for_create(:create, %{product_id: product_id, components: components},
      actor: actor,
      authorize?: authorize?
    )
    |> Ash.create(actor: actor, authorize?: authorize?)

    :ok
  end

  defp update_recipe(_recipe, [], _actor, _authorize?), do: :ok

  defp update_recipe(recipe, components, actor, authorize?) do
    recipe
    |> Ash.Changeset.for_update(:update, %{components: components},
      actor: actor,
      authorize?: authorize?
    )
    |> Ash.update(actor: actor, authorize?: authorize?)

    :ok
  end

  defp load_recipe(product, actor, authorize?) do
    case Map.get(product, :recipe) do
      %NotLoaded{} ->
        case Ash.load(product, [recipe: [components: [material: [:name, :price]]]],
               actor: actor,
               authorize?: authorize?
             ) do
          {:ok, loaded_product} -> Map.get(loaded_product, :recipe)
          _ -> nil
        end

      recipe ->
        ensure_recipe_components_loaded(recipe, actor, authorize?)
    end
  end

  defp ensure_recipe_components_loaded(nil, _actor, _authorize?), do: nil

  defp ensure_recipe_components_loaded(%Recipe{} = recipe, actor, authorize?) do
    case recipe do
      %Recipe{components: %NotLoaded{}} ->
        Ash.load!(recipe,
          components: [material: [:name, :price]],
          actor: actor,
          authorize?: authorize?
        )

      _ ->
        recipe
    end
  end
end
