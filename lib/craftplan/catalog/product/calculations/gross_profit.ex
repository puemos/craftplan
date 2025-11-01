defmodule Craftplan.Catalog.Product.Calculations.GrossProfit do
  @moduledoc false

  use Ash.Resource.Calculation

  alias Ash.NotLoaded
  alias Craftplan.DecimalHelpers
  alias Decimal, as: D

  @impl true
  def init(_opts), do: {:ok, []}

  @impl true
  def load(_query, _opts, _context), do: [:bom_unit_cost]

  @impl true
  def calculate(records, _opts, _context) do
    Enum.map(records, fn record ->
      price = DecimalHelpers.to_decimal(record.price)

      case record.bom_unit_cost do
        %NotLoaded{} -> D.sub(price, D.new(0))
        nil -> D.sub(price, D.new(0))
        unit_cost -> D.sub(price, DecimalHelpers.to_decimal(unit_cost))
      end
    end)
  end
end
