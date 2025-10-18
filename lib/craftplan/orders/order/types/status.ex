defmodule Craftplan.Orders.Order.Types.Status do
  @moduledoc false
  use Ash.Type.Enum,
    values: [
      :unconfirmed,
      :confirmed,
      :in_progress,
      :ready,
      :delivered,
      :completed,
      :cancelled
    ]
end
