defmodule Microcraft.Orders.Order.Types.Status do
  @moduledoc false
  use Ash.Type.Enum,
    values: [
      :unconfirmed,
      :confirmed,
      :in_process,
      :ready,
      :delivered,
      :completed,
      :cancelled
    ]
end
