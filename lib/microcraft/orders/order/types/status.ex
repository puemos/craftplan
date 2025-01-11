defmodule Microcraft.Orders.Order.Types.Status do
  @moduledoc false
  use Ash.Type.Enum,
    values: [
      # Initial order creation
      :created,
      # Awaiting payment
      :payment_pending,
      # Payment received
      :payment_confirmed,
      # Order being processed
      :processing,
      # Order packed and ready
      :packed,
      # Order in delivery
      :in_transit,
      # Order received by customer
      :delivered,
      # Order fully complete
      :completed,
      # Order refunded
      :refunded,
      # Order cancelled
      :cancelled
    ]
end
