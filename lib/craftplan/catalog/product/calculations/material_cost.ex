defmodule Craftplan.Catalog.Product.Calculations.MaterialCost do
  @moduledoc false

  use Ash.Resource.Calculation

  alias Ash.NotLoaded
  alias Craftplan.Catalog.Services.BatchCostCalculator
  alias Decimal, as: D

  @impl true
  def init(_opts), do: {:ok, []}

  @impl true
  def load(_query, _opts, _context) do
    [
      active_bom: [
        :rollup,
        components: [:component_type, material: [:price]],
        labor_steps: []
      ],
      recipe: [components: [material: [:price]]]
    ]
  end

  @impl true
  def calculate(records, _opts, _arguments) do
    Enum.map(records, &material_cost/1)
  end

  defp material_cost(%{active_bom: %NotLoaded{}} = record), do: material_cost_from_recipe(record)
  defp material_cost(%{active_bom: nil} = record), do: material_cost_from_recipe(record)

  defp material_cost(%{active_bom: bom}) do
    case Map.get(bom, :rollup) do
      %NotLoaded{} -> compute_material_cost(bom)
      nil -> compute_material_cost(bom)
      rollup -> Map.get(rollup, :material_cost) || D.new(0)
    end
  end

  defp compute_material_cost(bom) do
    bom
    |> BatchCostCalculator.calculate(D.new(1), authorize?: false)
    |> Map.get(:material_cost, D.new(0))
  rescue
    _ -> D.new(0)
  end

  defp material_cost_from_recipe(%{recipe: %NotLoaded{}}), do: D.new(0)
  defp material_cost_from_recipe(%{recipe: nil}), do: D.new(0)

  defp material_cost_from_recipe(%{recipe: recipe}) do
    Enum.reduce(recipe.components, D.new(0), fn component, acc ->
      quantity = normalize_decimal(component_quantity(component))
      price = normalize_decimal(component_price(component))

      D.add(acc, D.mult(price, quantity))
    end)
  end

  defp component_quantity(component) do
    case Map.get(component, :quantity) do
      %NotLoaded{} -> nil
      value -> value
    end
  end

  defp component_price(component) do
    component
    |> Map.get(:material)
    |> case do
      nil -> nil
      %NotLoaded{} -> nil
      material -> Map.get(material, :price)
    end
  end

  defp normalize_decimal(%D{} = value), do: value
  defp normalize_decimal(nil), do: D.new(0)
  defp normalize_decimal(value) when is_integer(value), do: D.new(value)
  defp normalize_decimal(value) when is_float(value), do: D.from_float(value)
  defp normalize_decimal(value) when is_binary(value), do: D.new(value)
  defp normalize_decimal(_), do: D.new(0)
end
