defmodule Craftplan.Catalog.Product.Calculations.NutritionalFacts do
  @moduledoc """
  Calculates all the nutritional facts for a product based on its active BOM.
  """
  use Ash.Resource.Calculation

  @impl true
  def init(_opts), do: {:ok, []}

  @impl true
  def load(_query, _opts, _context) do
    [
      active_bom: [
        components: [
          :component_type,
          :quantity,
          material: [
            material_nutritional_facts: [
              :amount,
              :unit,
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

  defp calculate_nutritional_facts(%{active_bom: %Ash.NotLoaded{}}), do: []
  defp calculate_nutritional_facts(%{active_bom: nil}), do: []

  defp calculate_nutritional_facts(%{active_bom: bom}) do
    bom.components
    |> Enum.filter(&(&1.component_type == :material))
    |> extract_nutritional_facts()
    |> group_and_sum_facts()
    |> Enum.sort_by(& &1.name)
  end

  defp extract_nutritional_facts(components) do
    Enum.flat_map(components, fn component ->
      Enum.map(component.material.material_nutritional_facts, fn fact ->
        qty = to_decimal(component.quantity)
        amt = to_decimal(fact.amount)

        %{
          name: fact.nutritional_fact.name,
          amount: Decimal.mult(amt, qty),
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

  defp to_decimal(%Decimal{} = d), do: d
  defp to_decimal(%Ash.NotLoaded{}), do: Decimal.new(0)
  defp to_decimal(nil), do: Decimal.new(0)
  defp to_decimal(v) when is_binary(v), do: Decimal.new(v)
  defp to_decimal(v) when is_integer(v), do: Decimal.new(v)
  defp to_decimal(v) when is_float(v), do: Decimal.from_float(v)
  defp to_decimal(_), do: Decimal.new(0)
end
