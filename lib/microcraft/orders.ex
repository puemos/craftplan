defmodule Microcraft.Orders do
  use Ash.Domain

  resources do
    resource Microcraft.Orders.Order
    resource Microcraft.Orders.OrderItem
  end
end
