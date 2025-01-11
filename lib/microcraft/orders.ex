defmodule Microcraft.Orders do
  @moduledoc false
  use Ash.Domain

  resources do
    resource Microcraft.Orders.Order do
      define :get_order_by_id, action: :read, get_by: [:id]
      define :get_order_by_reference, action: :read, get_by: [:reference]
      define :list_orders, action: :list
      define :list_orders_with_keyset, action: :keyset
    end

    resource Microcraft.Orders.OrderItem
  end
end
