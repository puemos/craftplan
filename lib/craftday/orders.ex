defmodule Craftday.Orders do
  @moduledoc false
  use Ash.Domain

  resources do
    resource Craftday.Orders.Order do
      define :get_order_by_id, action: :read, get_by: [:id]
      define :get_order_by_reference, action: :read, get_by: [:reference]
      define :list_orders, action: :list
      define :list_orders_with_keyset, action: :keyset
    end

    resource Craftday.Orders.OrderItem do
      define :get_order_item_by_id, action: :read, get_by: [:id]
      define :update_item, action: :update
    end
  end
end
