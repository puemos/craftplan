defmodule Craftday.Cart.Cart do
  @moduledoc false
  use Ash.Resource,
    otp_app: :craftday,
    domain: Craftday.Cart,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table "cart"
    repo Craftday.Repo
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      primary? true

      argument :items, {:array, :map}

      change manage_relationship(:items, type: :direct_control)
    end

    update :update do
      require_atomic? false

      argument :items, {:array, :map}

      change manage_relationship(:items, type: :direct_control)
    end

    read :list do
      prepare build(sort: [inserted_at: :desc], load: [items: [:product]])

      pagination do
        required? false
        offset? true
        countable true
      end
    end
  end

  policies do
    # Admin/staff can do anything
    bypass expr(^actor(:role) in [:admin, :staff]) do
      authorize_if always()
    end

    # Anyone can create a cart
    policy action_type(:create) do
      authorize_if always()
    end

    # Only allow access when session cart matches
    policy action_type(:read) do
      authorize_if expr(id == ^context(:cart_id))
    end

    policy action_type([:update, :destroy]) do
      authorize_if expr(id == ^context(:cart_id))
    end
  end

  attributes do
    uuid_primary_key :id
    timestamps()
  end

  relationships do
    has_many :items, Craftday.Cart.CartItem
  end

  aggregates do
    sum :total_items, :items, :quantity
  end
end
