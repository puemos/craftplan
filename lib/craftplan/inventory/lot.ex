defmodule Craftplan.Inventory.Lot do
  @moduledoc false
  use Ash.Resource,
    otp_app: :craftplan,
    domain: Craftplan.Inventory,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [AshJsonApi.Resource, AshGraphql.Resource]

  json_api do
    type "lot"

    routes do
      base("/lots")
      get(:read)
      index :read
    end
  end

  graphql do
    type :lot

    queries do
      get(:get_lot, :read)
      list(:list_lots, :read)
    end
  end

  postgres do
    table "inventory_lots"
    repo Craftplan.Repo

    custom_indexes do
      index [:lot_code], unique: true, name: "inventory_lots_lot_code_index"
      index [:supplier_lot_code], name: "inventory_lots_supplier_lot_code_index"
      index [:material_id], name: "inventory_lots_material_id_index"
      index [:supplier_id], name: "inventory_lots_supplier_id_index"
      index [:purchase_order_item_id], name: "inventory_lots_purchase_order_item_id_index"
    end
  end

  actions do
    defaults [
      :read,
      create: [
        :lot_code,
        :supplier_lot_code,
        :received_quantity,
        :expiry_date,
        :received_at,
        :material_id,
        :supplier_id,
        :purchase_order_item_id,
        :unit_cost
      ]
    ]

    read :available_for_material do
      argument :material_id, :uuid, allow_nil?: false

      filter expr(material_id == ^arg(:material_id) and status == :available and current_stock > 0)

      prepare build(load: [:current_stock], sort: [expiry_date: :asc])
    end

    update :place_on_hold do
      accept []
      change set_attribute(:status, :on_hold)
    end

    update :release_hold do
      accept []
      change set_attribute(:status, :available)
    end

    update :reject do
      accept []
      change set_attribute(:status, :rejected)
    end
  end

  policies do
    # API key scope check
    policy always() do
      authorize_if {Craftplan.Accounts.Checks.ApiScopeCheck, []}
    end

    policy action_type(:read) do
      authorize_if always()
    end

    policy action_type([:create, :update, :destroy]) do
      authorize_if expr(^actor(:role) in [:staff, :admin])
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :lot_code, :string do
      allow_nil? false
    end

    attribute :supplier_lot_code, :string do
      allow_nil? true
      description "Lot or batch identifier printed by the supplier."
    end

    attribute :received_quantity, :decimal do
      allow_nil? false
      default 0
      constraints min: 0
      description "Quantity originally received into this lot."
    end

    attribute :status, :atom do
      allow_nil? false
      default :available
      constraints one_of: [:available, :on_hold, :rejected]
    end

    attribute :expiry_date, :date do
      allow_nil? true
    end

    attribute :received_at, :utc_datetime do
      allow_nil? true
    end

    attribute :unit_cost, :decimal do
      allow_nil? true
      description "Cost per unit (in Material.unit) at time of receipt. Frozen on this lot."
    end

    timestamps()
  end

  relationships do
    belongs_to :material, Craftplan.Inventory.Material do
      allow_nil? false
    end

    belongs_to :supplier, Craftplan.Inventory.Supplier do
      allow_nil? true
    end

    belongs_to :purchase_order_item, Craftplan.Inventory.PurchaseOrderItem do
      allow_nil? true
    end

    has_many :movements, Craftplan.Inventory.Movement
  end

  aggregates do
    sum :current_stock, :movements, :quantity
  end
end
