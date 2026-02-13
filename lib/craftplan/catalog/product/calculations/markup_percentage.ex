defmodule Craftplan.Catalog.Product.Calculations.MarkupPercentage do
  @moduledoc false

  use Ash.Resource.Calculation

  alias Ash.NotLoaded

  @impl true
  def init(_opts), do: {:ok, []}

  @impl true
  def load(_query, _opts, _context), do: [:bom_unit_cost]

  @impl true
  def calculate(records, opts, _context) do
    currency = Craftplan.Settings.get_settings!().currency

    Enum.map(records, fn record ->
      case record.bom_unit_cost do
        %NotLoaded{} ->
          Decimal.new(0)

        nil ->
          Decimal.new(0)

        unit_cost ->
          if Money.compare(unit_cost, Money.new!(0, currency)) == :eq do
            Decimal.new(0)
          else
            Money.to_decimal(Money.div!(Money.sub!(record.price, unit_cost), Money.to_decimal(unit_cost)))
          end
      end
    end)
  end
end
