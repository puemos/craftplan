defmodule Craftplan.Orders do
  @moduledoc false
  use Ash.Domain

  alias Craftplan.Orders.Order

  resources do
    resource Order do
      define :get_order_by_id, action: :read, get_by: [:id]
      define :get_order_by_reference, action: :read, get_by: [:reference]
      define :list_orders, action: :list
      define :list_orders_with_keyset, action: :keyset
    end

    resource Craftplan.Orders.OrderItem do
      define :get_order_item_by_id, action: :read, get_by: [:id]
      define :update_item, action: :update
    end

    resource Craftplan.Orders.ProductionBatch do
      define :get_production_batch_by_id, action: :read, get_by: [:id]
      define :get_production_batch_by_code, action: :by_code
      define :list_production_batches, action: :read
    end

    resource Craftplan.Orders.OrderItemLot do
      define :list_order_item_lots, action: :read
    end

    resource Craftplan.Orders.OrderItemBatchAllocation do
      define :list_order_item_batch_allocations, action: :read
      define :create_order_item_batch_allocation, action: :create
      define :update_order_item_batch_allocation, action: :update
      define :destroy_order_item_batch_allocation, action: :destroy
    end
  end
end
