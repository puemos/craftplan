defmodule Craftplan.Catalog.Product.Calculations.GrossProfit do
  @moduledoc false

  use Ash.Resource.Calculation

  alias Ash.NotLoaded
  alias Decimal, as: D

  @impl true
  def init(_opts), do: {:ok, []}

  @impl true
  def load(_query, _opts, _context), do: [:bom_unit_cost]

  @impl true
  def calculate(records, _opts, _context) do
    Enum.map(records, fn record ->
      price = to_decimal(record.price)

      case record.bom_unit_cost do
        %NotLoaded{} -> D.sub(price, D.new(0))
        nil -> D.sub(price, D.new(0))
        unit_cost -> D.sub(price, to_decimal(unit_cost))
      end
    end)
  end

  defp to_decimal(%D{} = d), do: d
  defp to_decimal(nil), do: D.new(0)
  defp to_decimal(val) when is_binary(val), do: D.new(val)
  defp to_decimal(val) when is_integer(val), do: D.new(val)
  defp to_decimal(val) when is_float(val), do: D.from_float(val)
  defp to_decimal(_), do: D.new("0")
end
