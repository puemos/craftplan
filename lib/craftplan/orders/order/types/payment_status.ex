defmodule Craftplan.Orders.Order.Types.PaymentStatus do
  @moduledoc false
  use Ash.Type.Enum,
    values: [
      :pending,
      :paid,
      :to_be_refunded,
      :refunded
    ]
end
