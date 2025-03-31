defmodule Microcraft.Catalog.Product.Calculations.Allergens do
  @moduledoc false
  use Ash.Resource.Calculation

  @impl true
  def init(_opts) do
    {:ok, []}
  end

  @impl true
  def load(_query, _opts, _context) do
    [
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
      case record.recipe do
        nil ->
          []

        recipe ->
          recipe.components
          |> Enum.flat_map(& &1.material.allergens)
          |> Enum.uniq_by(& &1.name)
          |> Enum.sort_by(& &1.name)
      end
    end)
  end
end
