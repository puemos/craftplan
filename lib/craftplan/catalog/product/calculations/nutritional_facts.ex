defmodule Craftplan.Catalog.Product.Calculations.NutritionalFacts do
  @moduledoc """
  Calculates all the nutritional facts for a product based on its active BOM.
  """
  use Ash.Resource.Calculation

  alias Craftplan.DecimalHelpers
  alias Craftplan.Inventory.Nutrition
  alias Decimal, as: D

  @impl true
  def init(_opts), do: {:ok, []}

  @impl true
  def load(_query, _opts, _context) do
    [
      :nutrition_output_quantity,
      :nutrition_output_unit,
      active_bom: [
        components: [
          :component_type,
          :quantity,
          material: [
            :unit,
            material_nutritional_facts: [
              :amount,
              :unit,
              :basis_quantity,
              :basis_unit,
              nutritional_fact: [
                :key,
                :name,
                :parent_key,
                :sort_order,
                :eu_required
              ]
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

  defp calculate_nutritional_facts(%{active_bom: %Ash.NotLoaded{}}), do: []
  defp calculate_nutritional_facts(%{active_bom: nil}), do: []

  defp calculate_nutritional_facts(%{active_bom: bom} = product) do
    bom.components
    |> Enum.filter(&(&1.component_type == :material))
    |> extract_nutritional_facts()
    |> group_and_sum_facts()
    |> scale_to_declaration_basis(product)
    |> Enum.sort_by(&{&1.sort_order || 1000, &1.name})
  end

  defp extract_nutritional_facts(components) do
    Enum.flat_map(components, fn component ->
      Enum.map(component.material.material_nutritional_facts, fn fact ->
        qty = DecimalHelpers.to_decimal(component.quantity)
        amt = DecimalHelpers.to_decimal(fact.amount)
        basis = positive_decimal(fact.basis_quantity, D.new(100))

        %{
          key: fact.nutritional_fact.key || fact.nutritional_fact.name,
          name: fact.nutritional_fact.name,
          amount: D.div(D.mult(amt, qty), basis),
          unit: fact.unit,
          parent_key: fact.nutritional_fact.parent_key,
          sort_order: fact.nutritional_fact.sort_order || 1000,
          eu_required: fact.nutritional_fact.eu_required || false,
          basis_unit: fact.basis_unit,
          material_unit: component.material.unit
        }
      end)
    end)
  end

  defp group_and_sum_facts(facts) do
    facts
    |> Enum.group_by(& &1.key)
    |> Enum.map(fn {_key, grouped_facts} ->
      first = List.first(grouped_facts)
      total_amount = sum_amounts(grouped_facts)

      %{
        key: first.key,
        name: first.name,
        amount: total_amount,
        unit: first.unit,
        parent_key: first.parent_key,
        sort_order: first.sort_order,
        eu_required: first.eu_required,
        per_quantity: nil,
        per_unit: nil,
        declaration?: false
      }
    end)
  end

  defp scale_to_declaration_basis(facts, product) do
    output_quantity = Map.get(product, :nutrition_output_quantity)
    output_unit = Map.get(product, :nutrition_output_unit)

    if Nutrition.declaration_output?(output_quantity, output_unit) do
      scale = D.div(D.new(100), DecimalHelpers.to_decimal(output_quantity))

      Enum.map(facts, fn fact ->
        %{
          fact
          | amount: D.mult(fact.amount, scale),
            per_quantity: D.new(100),
            per_unit: output_unit,
            declaration?: true
        }
      end)
    else
      facts
    end
  end

  defp sum_amounts(facts) do
    Enum.reduce(facts, D.new(0), fn fact, acc ->
      D.add(acc, fact.amount)
    end)
  end

  defp positive_decimal(value, fallback) do
    value = DecimalHelpers.to_decimal(value)

    if D.compare(value, D.new(0)) == :gt do
      value
    else
      fallback
    end
  end
end
