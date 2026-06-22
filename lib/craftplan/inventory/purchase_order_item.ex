defmodule Craftplan.Inventory.PurchaseOrderItem do
  @moduledoc false
  use Ash.Resource,
    otp_app: :craftplan,
    domain: Craftplan.Inventory,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [AshJsonApi.Resource, AshGraphql.Resource]

  json_api do
    type "purchase-order-item"

    routes do
      base("/purchase-order-items")
      get(:read)
      index :list
      post(:create)
      patch(:update)
    end
  end

  graphql do
    type :purchase_order_item

    queries do
      get(:get_purchase_order_item, :read)
      list(:list_purchase_order_items, :list)
    end

    mutations do
      create :create_purchase_order_item, :create
      update :update_purchase_order_item, :update
    end
  end

  postgres do
    table "inventory_purchase_order_items"
    repo Craftplan.Repo
  end

  actions do
    defaults [:read, :destroy]

    read :list do
      prepare build(sort: [inserted_at: :asc], load: [:material, :purchase_order])
    end

    read :open_for_material do
      argument :material_id, :uuid do
        allow_nil? false
      end

      prepare build(
                sort: [inserted_at: :asc],
                load: [
                  :material,
                  purchase_order: [:supplier]
                ],
                filter: expr(material_id == ^arg(:material_id) and purchase_order.status != :received)
              )
    end

    create :create do
      primary? true
      accept [:purchase_order_id, :material_id, :quantity, :unit_price]
    end

    update :update do
      accept [:quantity, :unit_price]
    end
  end

  policies do
    # API key scope check
    policy always() do
      authorize_if {Craftplan.Accounts.Checks.ApiScopeCheck, []}
    end

    policy action_type(:read) do
      authorize_if expr(^actor(:role) in [:staff, :admin])
    end

    policy action_type([:create, :update, :destroy]) do
      authorize_if expr(^actor(:role) in [:staff, :admin])
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :quantity, :decimal do
      public? true
      allow_nil? false
      default 0
    end

    attribute :unit_price, :decimal do
      public? true
      allow_nil? true
    end

    timestamps()
  end

  relationships do
    belongs_to :purchase_order, Craftplan.Inventory.PurchaseOrder do
      public? true
      allow_nil? false
    end

    belongs_to :material, Craftplan.Inventory.Material do
      public? true
      allow_nil? false
    end
  end
end
