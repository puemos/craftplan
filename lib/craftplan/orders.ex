defmodule Craftplan.Orders do
  @moduledoc false
  use Ash.Domain,
    extensions: [AshJsonApi.Domain, AshGraphql.Domain]

  alias Craftplan.Orders.Order

  json_api do
    prefix "/api/json"
  end

  graphql do
  end

  resources do
    resource Order do
      define :get_order_by_id, action: :read, get_by: [:id]
      define :get_order_by_reference, action: :read, get_by: [:reference]
      define :list_orders, action: :list
      define :list_orders_with_keyset, action: :keyset
      define :destroy_order, action: :destroy
    end

    resource Craftplan.Orders.OrderItem do
      define :get_order_item_by_id, action: :read, get_by: [:id]
      define :update_item, action: :update
      define :list_order_items_for_plan, action: :plan_pending
    end

    resource Craftplan.Orders.ProductionBatch do
      define :get_production_batch_by_id, action: :read, get_by: [:id]
      define :get_production_batch_by_code, action: :by_code
      define :list_production_batches, action: :read
      define :list_production_batches_filtered, action: :list
      define :list_production_batches_for_plan, action: :plan
      define :open_batch_with_allocations, action: :open_with_allocations
      define :start_batch, action: :start
      define :complete_batch, action: :complete
      define :list_open_batches_for_product, action: :open_for_product
    end

    resource Craftplan.Orders.OrderItemLot do
      define :list_order_item_lots, action: :read
    end

    resource Craftplan.Orders.OrderItemBatchAllocation do
      define :list_order_item_batch_allocations, action: :read
      define :create_order_item_batch_allocation, action: :create
      define :update_order_item_batch_allocation, action: :update
      define :destroy_order_item_batch_allocation, action: :destroy
      define :list_allocations_for_batch, action: :for_batch
    end

    resource Craftplan.Orders.ProductionBatchLot do
      define :create_production_batch_lot, action: :create
      define :list_production_batch_lots, action: :read
      define :destroy_production_batch_lot, action: :destroy
    end
  end
end
