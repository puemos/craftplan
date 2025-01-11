defmodule CraftScale.Orders.OrderItem do
  @moduledoc false
  use Ash.Resource,
    otp_app: :craftscale,
    domain: CraftScale.Orders,
    data_layer: AshPostgres.DataLayer

  postgres do
    table "orders_items"
    repo CraftScale.Repo
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      primary? true
      accept [:product_id, :quantity, :unit_price]
    end

    update :update do
      primary? true
      accept [:quantity]
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

    timestamps()
  end

  relationships do
    belongs_to :order, CraftScale.Orders.Order do
      allow_nil? false
    end

    belongs_to :product, CraftScale.Catalog.Product do
      allow_nil? false
    end
  end

  calculations do
    calculate :cost, :decimal, expr(quantity * unit_price)
  end
end
