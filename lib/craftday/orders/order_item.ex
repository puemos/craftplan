defmodule Craftday.Orders.OrderItem do
  @moduledoc false
  use Ash.Resource,
    otp_app: :craftday,
    domain: Craftday.Orders,
    data_layer: AshPostgres.DataLayer

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
      accept [:quantity, :status]
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
