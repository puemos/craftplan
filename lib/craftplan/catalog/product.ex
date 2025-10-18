defmodule Craftplan.Catalog.Product do
  @moduledoc false
  use Ash.Resource,
    otp_app: :craftplan,
    domain: Craftplan.Catalog,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table "catalog_products"
    repo Craftplan.Repo
  end

  actions do
    defaults [
      :read,
      :destroy,
      create: [
        :name,
        :status,
        :price,
        :sku,
        :photos,
        :featured_photo,
        :selling_availability,
        :max_daily_quantity
      ],
      update: [
        :name,
        :status,
        :price,
        :sku,
        :photos,
        :featured_photo,
        :selling_availability,
        :max_daily_quantity
      ]
    ]

    read :list do
      prepare build(sort: :name)

      argument :status, {:array, :atom} do
        allow_nil? true
        default nil
      end

      filter expr(is_nil(^arg(:status)) or status in ^arg(:status))

      pagination do
        required? false
        offset? true
        keyset? true
        countable true
      end
    end

    read :keyset do
      prepare build(sort: :name)
      pagination keyset?: true
    end
  end

  policies do
    # Admin can do anything
    bypass expr(^actor(:role) == :admin) do
      authorize_if always()
    end

    # Public read for active/available products; staff/admin read everything
    policy action_type(:read) do
      authorize_if expr(status == :active or selling_availability != :off)
      authorize_if expr(^actor(:role) in [:staff, :admin])
    end

    # Writes restricted to staff/admin
    policy action_type([:create, :update, :destroy]) do
      authorize_if expr(^actor(:role) in [:staff, :admin])
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :name, :string do
      allow_nil? false
      public? true

      constraints min_length: 2,
                  max_length: 100,
                  match: ~r/^[\w\s\-\.]+$/
    end

    attribute :status, Craftplan.Catalog.Product.Types.Status do
      allow_nil? false
      public? true
      default :draft
    end

    attribute :price, :decimal do
      public? true
      allow_nil? false
    end

    attribute :sku, :string do
      allow_nil? false
    end

    attribute :photos, {:array, :string} do
      public? true
      default []
      description "Array of photo URLs for the product"
    end

    attribute :featured_photo, :string do
      public? true
      allow_nil? true
      description "ID or reference to the featured photo from the photos array"
    end

    attribute :selling_availability, :atom do
      public? true
      allow_nil? false
      default :available
      constraints one_of: [:available, :preorder, :off]
      description "Customer-facing availability: available, preorder, or off"
    end

    attribute :max_daily_quantity, :integer do
      public? true
      allow_nil? false
      default 0
      constraints min: 0
      description "Optional per-product capacity per day (0 = unlimited)"
    end

    timestamps()
  end

  relationships do
    has_one :recipe, Craftplan.Catalog.Recipe do
      allow_nil? true
    end

    has_many :items, Craftplan.Orders.OrderItem
  end

  calculations do
    calculate :materials_cost, :decimal, expr(recipe.cost) do
      description "The total cost of the product."
    end

    calculate :markup_percentage,
              :decimal,
              expr(if(recipe.cost == 0, 0, (price - recipe.cost) / recipe.cost)) do
      description "The ratio of profit to cost, expressed as a decimal percentage"
    end

    calculate :gross_profit,
              :decimal,
              expr(price - recipe.cost) do
      description "The profit amount calculated as selling price minus material cost"
    end

    calculate :allergens, :vector, Craftplan.Catalog.Product.Calculations.Allergens

    calculate :nutritional_facts,
              :vector,
              Craftplan.Catalog.Product.Calculations.NutritionalFacts
  end

  identities do
    identity :sku, [:sku]
    identity :name, [:name]
  end
end
