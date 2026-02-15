defmodule Craftplan.Orders.OrderItem.Cost do
  @moduledoc false
  use Ash.Resource.Calculation

  @impl true
  def init(_opts) do
    {:ok, []}
  end

  @impl true
  def load(_query, _opts, _context), do: []

  @impl true
  def calculate(record, _opts, _context) do
    Money.mult!(Map.get(record, :unit_price), Map.get(record, :quantity))
  end
end
