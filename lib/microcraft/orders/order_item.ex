defmodule Microcraft.Orders.OrderItem do
  use Ash.Resource,
    otp_app: :microcraft,
    domain: Microcraft.Orders,
    data_layer: AshPostgres.DataLayer

  postgres do
    table "orders_items"
    repo Microcraft.Repo
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      primary? true
      accept [:product_id, :quantity]
    end

    update :update do
      primary? true
      accept [:quantity]
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :quantity, :decimal do
      allow_nil? false
    end

    timestamps()
  end

  relationships do
    belongs_to :order, Microcraft.Orders.Order do
      allow_nil? false
    end

    belongs_to :product, Microcraft.Catalog.Product do
      allow_nil? false
    end
  end

  calculations do
    calculate :cost, :decimal, expr(quantity * product.price)
  end
end
