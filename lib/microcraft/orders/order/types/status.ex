defmodule CraftScale.Orders.Order.Types.Status do
  @moduledoc false
  use Ash.Type.Enum, values: [:pending, :approved, :fulfilled, :shipped, :cancelled]
end
