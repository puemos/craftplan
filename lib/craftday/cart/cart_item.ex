defmodule Craftday.Cart.CartItem do
  @moduledoc false
  use Ash.Resource,
    otp_app: :craftday,
    domain: Craftday.Cart,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
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

  policies do
    # Admin/staff can do anything
    bypass expr(^actor(:role) in [:admin, :staff]) do
      authorize_if always()
    end

    # Create allowed for anyone (tied to a cart id)
    policy action_type(:create) do
      authorize_if always()
    end

    # Read/update/destroy allowed only for matching cart via context
    policy action_type(:read) do
      authorize_if expr(cart_id == ^context(:cart_id))
    end

    policy action_type([:update, :destroy]) do
      authorize_if expr(cart_id == ^context(:cart_id))
    end
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
