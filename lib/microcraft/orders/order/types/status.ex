defmodule Microcraft.Orders.Order.Types.Status do
  @moduledoc false
  use Ash.Type.Enum, values: [:pending, :fulfilled, :shipped, :cancelled]
end
