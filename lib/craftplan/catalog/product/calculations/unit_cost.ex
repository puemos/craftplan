defmodule Craftplan.Catalog.Product.Calculations.UnitCost do
  @moduledoc """
  Calculates the total unit cost for a product from its active BOM rollup.
  """

  use Ash.Resource.Calculation

  alias Ash.NotLoaded
  alias Decimal, as: D

  @impl true
  def load(_query, _opts, _context), do: [active_bom: [rollup: [:unit_cost]]]

  @impl true
  def calculate(records, _opts, _context) do
    Enum.map(records, fn record ->
      rollup =
        case Map.get(record, :active_bom) do
          %NotLoaded{} -> nil
          nil -> nil
          bom -> Map.get(bom, :rollup)
        end

      unit_cost =
        case rollup do
          %NotLoaded{} -> nil
          nil -> nil
          rollup -> Map.get(rollup, :unit_cost)
        end

      case unit_cost do
        %NotLoaded{} -> D.new(0)
        nil -> D.new(0)
        cost -> cost
      end
    end)
  end
end
