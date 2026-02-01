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
    defaults [:read, :destroy]

    read :for_batch do
      argument :production_batch_id, :uuid, allow_nil?: false
      filter expr(production_batch_id == ^arg(:production_batch_id))
      prepare build(load: [order_item: [order: [:reference], product: [:name]]])
    end

    create :create do
      primary? true
      accept [:production_batch_id, :order_item_id, :planned_qty, :completed_qty]
    end

    update :update do
      primary? true
      accept [:planned_qty, :completed_qty]
      require_atomic? false
    end
  end

  policies do
    policy action_type(:read) do
      authorize_if expr(^actor(:role) in [:staff, :admin])
    end

    policy action_type([:create, :update, :destroy]) do
      authorize_if expr(^actor(:role) in [:staff, :admin])
    end
  end

  validations do
    validate {Craftplan.Orders.Validations.AllocationProductMatch, []}
    # Ensure completed never exceeds planned
    validate compare(:completed_qty, less_than_or_equal_to: :planned_qty) do
      message "completed quantity must be less than or equal to planned quantity"
    end

    # Guard rail: total planned across all allocations for an item cannot exceed item quantity
    validate {Craftplan.Orders.Validations.AllocationWithinItemQuantity, []}
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
