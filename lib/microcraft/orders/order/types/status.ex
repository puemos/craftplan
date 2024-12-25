defmodule Microcraft.Orders.Order.Types.Status do
  use Ash.Type.Enum, values: [:pending, :fulfilled, :shipped, :cancelled]
end
