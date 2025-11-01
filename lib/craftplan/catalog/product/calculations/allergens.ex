defmodule Craftplan.Catalog.Product.Calculations.Allergens do
  @moduledoc false
  use Ash.Resource.Calculation

  @impl true
  def init(_opts) do
    {:ok, []}
  end

  @impl true
  def load(_query, _opts, _context) do
    [
      active_bom: [
        components: [
          :component_type,
          material: [allergens: [:name]]
        ]
      ],
      recipe: [
        components: [
          material: [allergens: [:name]]
        ]
      ]
    ]
  end

  @impl true
  def calculate(records, _opts, _arguments) do
    Enum.map(records, fn record ->
      case record.active_bom do
        %Ash.NotLoaded{} -> allergen_list_from_recipe(record.recipe)
        nil -> allergen_list_from_recipe(record.recipe)
        bom -> allergen_list_from_bom(bom)
      end
    end)
  end

  defp allergen_list_from_bom(bom) do
    bom.components
    |> Enum.filter(&(&1.component_type == :material))
    |> Enum.flat_map(fn component -> component.material.allergens end)
    |> Enum.uniq_by(& &1.name)
    |> Enum.sort_by(& &1.name)
  end

  defp allergen_list_from_recipe(%Ash.NotLoaded{}), do: []
  defp allergen_list_from_recipe(nil), do: []

  defp allergen_list_from_recipe(recipe) do
    recipe.components
    |> Enum.flat_map(fn component -> component.material.allergens end)
    |> Enum.uniq_by(& &1.name)
    |> Enum.sort_by(& &1.name)
  end
end
