defmodule Craftday.Catalog.Product.Calculations.NutritionalFacts do
  @moduledoc """
  Calculates all the nutritional facts for a product based on its recipe.
  """
  use Ash.Resource.Calculation

  @impl true
  def init(_opts), do: {:ok, []}

  @impl true
  def load(_query, _opts, _context) do
    [
      recipe: [
        components: [
          material: [
            material_nutritional_facts: [
              :amount,
              nutritional_fact: [:name]
            ]
          ]
        ]
      ]
    ]
  end

  @impl true
  def calculate(records, _opts, _arguments) do
    Enum.map(records, &calculate_nutritional_facts/1)
  end

  defp calculate_nutritional_facts(%{recipe: nil}), do: []

  defp calculate_nutritional_facts(%{recipe: recipe}) do
    recipe = load_recipe_with_nutritional_facts(recipe)

    recipe.components
    |> extract_nutritional_facts()
    |> group_and_sum_facts()
    |> Enum.sort_by(& &1.name)
  end

  defp load_recipe_with_nutritional_facts(recipe) do
    Ash.load!(recipe,
      components: [material: [material_nutritional_facts: [nutritional_fact: [:name]]]]
    )
  end

  defp extract_nutritional_facts(components) do
    Enum.flat_map(components, fn component ->
      Enum.map(component.material.material_nutritional_facts, fn fact ->
        %{
          name: fact.nutritional_fact.name,
          amount: Decimal.mult(fact.amount, component.quantity),
          unit: fact.unit
        }
      end)
    end)
  end

  defp group_and_sum_facts(facts) do
    facts
    |> Enum.group_by(& &1.name)
    |> Enum.map(fn {name, grouped_facts} ->
      total_amount = sum_amounts(grouped_facts)
      unit = List.first(grouped_facts).unit

      %{name: name, amount: total_amount, unit: unit}
    end)
  end

  defp sum_amounts(facts) do
    Enum.reduce(facts, Decimal.new(0), fn fact, acc ->
      Decimal.add(acc, fact.amount)
    end)
  end
end
