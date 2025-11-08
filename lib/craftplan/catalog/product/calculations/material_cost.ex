defmodule Craftplan.Catalog.Product.Calculations.MaterialCost do
  @moduledoc """
  Calculates the material cost for a product from its active BOM rollup.
  """

  use Ash.Resource.Calculation

  alias Ash.NotLoaded
  alias Decimal, as: D

  @impl true
  def load(_query, _opts, _context), do: [active_bom: [rollup: [:material_cost]]]

  @impl true
  def calculate(records, _opts, _context) do
    Enum.map(records, &material_cost/1)
  end

  defp material_cost(record) do
    rollup =
      case Map.get(record, :active_bom) do
        %NotLoaded{} -> nil
        nil -> nil
        bom -> Map.get(bom, :rollup)
      end

    material_cost =
      case rollup do
        %NotLoaded{} -> nil
        nil -> nil
        rollup -> Map.get(rollup, :material_cost)
      end

    case material_cost do
      %NotLoaded{} -> D.new(0)
      nil -> D.new(0)
      cost -> cost
    end
  end
end
