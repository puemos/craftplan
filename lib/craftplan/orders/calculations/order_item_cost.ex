defmodule Craftplan.Orders.OrderItem.Cost do
  @moduledoc false
  use Ash.Resource.Calculation

  @impl true
  def init(_opts), do: {:ok, []}

  @impl true
  def load(_query, _opts, _context), do: []

  @impl true
  def calculate(records, _opts, _context) do
    Enum.map(records, fn x ->
      cost(x)
    end)
  end

  def cost(record) do
    Money.mult!(Map.get(record, :unit_price), Map.get(record, :quantity))
  end
end
