defmodule Craftplan.Orders.OrderItemLot do
  @moduledoc false
  use Ash.Resource,
    otp_app: :craftplan,
    domain: Craftplan.Orders,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table "orders_item_lots"
    repo Craftplan.Repo
  end

  actions do
    defaults [
      :read,
      :destroy,
      create: [:order_item_id, :lot_id, :quantity_used]
    ]
  end

  policies do
    policy action_type(:read) do
      authorize_if always()
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
    end

    timestamps()
  end

  relationships do
    belongs_to :order_item, Craftplan.Orders.OrderItem do
      allow_nil? false
    end

    belongs_to :lot, Craftplan.Inventory.Lot do
      allow_nil? false
    end
  end
end

