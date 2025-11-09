defmodule Craftplan.Orders.ProductionBatchLot do
  @moduledoc false
  use Ash.Resource,
    otp_app: :craftplan,
    domain: Craftplan.Orders,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table "orders_production_batch_lots"
    repo Craftplan.Repo

    custom_indexes do
      index [:production_batch_id], name: "orders_production_batch_lots_batch_idx"
      index [:lot_id], name: "orders_production_batch_lots_lot_idx"
    end
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      accept [:production_batch_id, :lot_id, :quantity_used]
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

  attributes do
    uuid_primary_key :id

    attribute :quantity_used, :decimal do
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

    belongs_to :lot, Craftplan.Inventory.Lot do
      allow_nil? false
    end
  end
end
