defmodule Craftday.Inventory.PurchaseOrderItem do
  @moduledoc false
  use Ash.Resource,
    otp_app: :craftday,
    domain: Craftday.Inventory,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table "inventory_purchase_order_items"
    repo Craftday.Repo
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
      allow_nil? false
      default 0
    end

    attribute :unit_price, :decimal do
      allow_nil? true
    end

    timestamps()
  end

  relationships do
    belongs_to :purchase_order, Craftday.Inventory.PurchaseOrder do
      allow_nil? false
    end

    belongs_to :material, Craftday.Inventory.Material do
      allow_nil? false
    end
  end
end
