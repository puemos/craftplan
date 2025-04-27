defmodule Craftday.Cart.CartItem do
  @moduledoc false
  use Ash.Resource,
    otp_app: :craftday,
    domain: Craftday.Cart,
    data_layer: AshPostgres.DataLayer,
    notifiers: [Ash.Notifier.PubSub]

  postgres do
    table "cart_items"
    repo Craftday.Repo
  end

  actions do
    defaults [
      :read,
      :destroy,
      create: [:quantity, :product_id, :price, :cart_id],
      update: [:quantity]
    ]
  end

  pub_sub do
    module CraftdayWeb.Endpoint

    prefix "cart_items"
    publish_all :update, [[:id, nil]]
    publish_all :create, [[:id, nil]]
    publish_all :destroy, [[:id, nil]]
  end

  attributes do
    uuid_primary_key :id

    attribute :quantity, :integer do
      allow_nil? false
      default 1
      constraints min: 1
    end

    attribute :price, :decimal do
      allow_nil? false
    end

    timestamps()
  end

  relationships do
    belongs_to :cart, Craftday.Cart.Cart do
      allow_nil? false
    end

    belongs_to :product, Craftday.Catalog.Product do
      allow_nil? false
      domain Craftday.Catalog
    end
  end
end
