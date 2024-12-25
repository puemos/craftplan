defmodule Microcraft.Orders.Order do
  use Ash.Resource,
    otp_app: :microcraft,
    domain: Microcraft.Orders,
    data_layer: AshPostgres.DataLayer

  postgres do
    table "orders_orders"
    repo Microcraft.Repo
  end

  actions do
    defaults [:read, :destroy, create: [:customer_name, :status], update: [:status]]
  end

  attributes do
    uuid_primary_key :id

    attribute :customer_name, :string do
      allow_nil? false
    end

    attribute :status, Microcraft.Orders.Order.Types.Status do
      allow_nil? false
      default :pending
    end

    timestamps()
  end

  relationships do
    has_many :order_items, Microcraft.Orders.OrderItem

    belongs_to :customer, Microcraft.CRM.Customer do
      allow_nil? false
    end
  end
end
