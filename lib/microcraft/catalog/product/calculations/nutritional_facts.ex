defmodule Microcraft.Catalog.Product.Calculations.NutritionalFacts do
  @moduledoc """
  Calculates all the nutritional facts for a product based on its recipe.
  """
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
    Enum.map(records, fn record ->
      case record.recipe do
        nil ->
          []

        recipe ->
          recipe =
            Ash.load!(recipe,
              components: [material: [material_nutritional_facts: [nutritional_fact: [:name]]]]
            )

          recipe.components
          |> Enum.flat_map(fn component ->
            Enum.map(component.material.material_nutritional_facts, fn fact ->
              # Create a map with name, amount, and unit for each nutritional fact
              %{
                name: fact.nutritional_fact.name,
                amount: Decimal.mult(fact.amount, component.quantity),
                unit: fact.unit
              }
            end)
          end)
          |> Enum.group_by(& &1.name)
          |> Enum.map(fn {name, facts} ->
            # For each nutritional fact name, sum the amounts (if units match)
            # This handles the case where multiple ingredients contribute to the same nutritional fact
            total_amount =
              Enum.reduce(facts, Decimal.new(0), fn fact, acc ->
                # In a real application, you'd want to handle unit conversion here
                # For simplicity, we're just adding amounts with the same unit
                Decimal.add(acc, fact.amount)
              end)

            # Use the unit from the first fact (ideally you'd ensure all units are compatible)
            unit = List.first(facts).unit

            %{name: name, amount: total_amount, unit: unit}
          end)
          |> Enum.sort_by(& &1.name)
      end
    end)
  end
end
