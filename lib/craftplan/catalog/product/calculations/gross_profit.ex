defmodule Craftplan.Catalog.Product.Calculations.GrossProfit do
  @moduledoc false

  use Ash.Resource.Calculation

  alias Ash.NotLoaded

  @impl true
  def init(_opts), do: {:ok, []}

  @impl true
  def load(_query, _opts, _context), do: [:bom_unit_cost]

  @impl true
  def calculate(records, _opts, _context) do
    currency = Craftplan.Settings.get_settings!().currency

    Enum.map(records, fn record ->
      case record.bom_unit_cost do
        %NotLoaded{} -> Money.sub!(record.price, Money.new!(0, currency))
        nil -> Money.sub!(record.price, Money.new!(0, currency))
        unit_cost -> Money.sub!(record.price, unit_cost)
      end
    end)
  end
end
