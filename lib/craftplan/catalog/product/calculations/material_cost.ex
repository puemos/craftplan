defmodule Craftplan.Catalog.Product.Calculations.MaterialCost do
  @moduledoc """
  Calculates the material cost for a product from its active BOM rollup.
  """

  use Ash.Resource.Calculation

  alias Ash.NotLoaded

  @impl true
  def load(_query, _opts, _context), do: [active_bom: [rollup: [:material_cost]]]

  @impl true
  def calculate(records, opts, _context) do
    currency = Craftplan.Settings.get_settings!().currency
    Enum.map(records, &material_cost(&1, currency))
  end

  defp material_cost(record, currency) do
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
      %NotLoaded{} -> Money.new!(0, currency)
      nil -> Money.new!(0, currency)
      cost -> cost
    end
  end
end
