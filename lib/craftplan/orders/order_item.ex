defmodule Craftplan.Orders.OrderItem do
  @moduledoc false
  use Ash.Resource,
    otp_app: :craftplan,
    domain: Craftplan.Orders,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table "orders_items"
    repo Craftplan.Repo
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      primary? true

      accept [:organization_id, :product_id, :quantity, :unit_price, :status]
    end

    update :update do
      primary? true
      require_atomic? false
      accept [:organization_id, :quantity, :status, :consumed_at]
    end

    read :in_range do
      description "Order items whose order delivery_date falls within a datetime range."

      argument :start_date, :utc_datetime do
        allow_nil? false
      end

      argument :end_date, :utc_datetime do
        allow_nil? false
      end

      argument :product_ids, {:array, :uuid} do
        allow_nil? true
        default nil
      end

      argument :exclude_order_id, :uuid do
        allow_nil? true
        default nil
      end

      prepare build(load: [:product, :order])

      # filter by the parent order's delivery_date
      filter expr(order.delivery_date >= ^arg(:start_date) and order.delivery_date <= ^arg(:end_date))

      # optionally filter by products
      filter expr(is_nil(^arg(:product_ids)) or product_id in ^arg(:product_ids))

      # optionally exclude items from a given order (useful during updates)
      filter expr(is_nil(^arg(:exclude_order_id)) or order_id != ^arg(:exclude_order_id))
    end
  end

  policies do
    # Public read allowed for `:in_range` (capacity checks)
    bypass action(:in_range) do
      authorize_if always()
    end

    # Other reads/writes restricted to staff/admin
    policy action_type(:read) do
      authorize_if expr(^actor(:role) in [:staff, :admin])
    end

    policy action_type([:create, :update, :destroy]) do
      authorize_if expr(^actor(:role) in [:staff, :admin])
    end
  end

  multitenancy do
    strategy :attribute
    attribute :organization_id
    global? true
  end

  attributes do
    uuid_primary_key :id

    attribute :organization_id, :uuid do
      allow_nil? true
      public? true
    end

    attribute :unit_price, :decimal do
      allow_nil? false
    end

    attribute :quantity, :decimal do
      allow_nil? false
    end

    attribute :status, Craftplan.Orders.OrderItem.Types.Status do
      allow_nil? false
      default :todo
    end

    attribute :consumed_at, :utc_datetime do
      allow_nil? true
      description "Timestamp indicating materials were consumed for this item"
    end

    timestamps()
  end

  relationships do
    belongs_to :organization, Craftplan.Organizations.Organization do
      attribute_type :uuid
      source_attribute :organization_id
      allow_nil? true
    end

    belongs_to :order, Craftplan.Orders.Order do
      allow_nil? false
    end

    belongs_to :product, Craftplan.Catalog.Product do
      allow_nil? false
    end
  end

  calculations do
    calculate :cost, :decimal, expr(quantity * unit_price)
  end
end
