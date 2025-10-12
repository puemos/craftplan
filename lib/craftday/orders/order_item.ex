defmodule Craftday.Orders.OrderItem do
  @moduledoc false
  use Ash.Resource,
    otp_app: :craftday,
    domain: Craftday.Orders,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table "orders_items"
    repo Craftday.Repo
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      primary? true
      accept [:product_id, :quantity, :unit_price, :status]
    end

    update :update do
      primary? true
      require_atomic? false
      accept [:quantity, :status, :consumed_at]
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

  attributes do
    uuid_primary_key :id

    attribute :unit_price, :decimal do
      allow_nil? false
    end

    attribute :quantity, :decimal do
      allow_nil? false
    end

    attribute :status, Craftday.Orders.OrderItem.Types.Status do
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
    belongs_to :order, Craftday.Orders.Order do
      allow_nil? false
    end

    belongs_to :product, Craftday.Catalog.Product do
      allow_nil? false
    end
  end

  calculations do
    calculate :cost, :decimal, expr(quantity * unit_price)
  end
end
