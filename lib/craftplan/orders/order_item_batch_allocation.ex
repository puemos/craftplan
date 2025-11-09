defmodule Craftplan.Orders.OrderItemBatchAllocation do
  @moduledoc false
  use Ash.Resource,
    otp_app: :craftplan,
    domain: Craftplan.Orders,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table "orders_item_batch_allocations"
    repo Craftplan.Repo

    custom_indexes do
      index [:production_batch_id, :order_item_id],
        unique: true,
        name: "orders_item_batch_allocations_unique_pair"

      index [:order_item_id], name: "orders_item_batch_allocations_item_idx"
      index [:production_batch_id], name: "orders_item_batch_allocations_batch_idx"
    end
  end

  actions do
    defaults [:read, :create, :update, :destroy]
  end

  policies do
    policy action_type(:read) do
      authorize_if expr(^actor(:role) in [:staff, :admin])
    end

    policy action_type([:create, :update, :destroy]) do
      authorize_if expr(^actor(:role) in [:staff, :admin])
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :planned_qty, :decimal do
      allow_nil? false
      default 0
      constraints min: 0
    end

    attribute :completed_qty, :decimal do
      allow_nil? false
      default 0
      constraints min: 0
    end

    timestamps()
  end

  relationships do
    belongs_to :production_batch, Craftplan.Orders.ProductionBatch do
      allow_nil? false
    end

    belongs_to :order_item, Craftplan.Orders.OrderItem do
      allow_nil? false
    end
  end
end
