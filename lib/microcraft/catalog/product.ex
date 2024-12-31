defmodule Microcraft.Catalog.Product do
  use Ash.Resource,
    otp_app: :microcraft,
    domain: Microcraft.Catalog,
    data_layer: AshPostgres.DataLayer

  postgres do
    table "catalog_products"
    repo Microcraft.Repo
  end

  actions do
    defaults [
      :read,
      :destroy,
      create: [:name, :status, :price, :sku],
      update: [:name, :status, :price, :sku]
    ]

    read :list do
      prepare build(sort: :name)

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

  attributes do
    uuid_primary_key :id

    attribute :name, :string do
      allow_nil? false
      public? true

      constraints min_length: 2,
                  max_length: 100,
                  match: ~r/^[\w\s\-\.]+$/
    end

    attribute :status, Microcraft.Catalog.Product.Types.Status do
      allow_nil? false
      public? true
      default :idea
    end

    attribute :price, :decimal do
      public? true
      allow_nil? false
    end

    attribute :sku, :string do
      allow_nil? false
    end

    timestamps()
  end

  relationships do
    has_one :recipe, Microcraft.Catalog.Recipe do
      allow_nil? true
    end
  end

  calculations do
    calculate :estimated_cost, :decimal, expr(recipe.cost) do
      description "The total cost of the product."
    end

    calculate :profit_margin,
              :decimal,
              expr(if(recipe.cost == 0, 0, (price - recipe.cost) / recipe.cost)) do
      description "The total cost of the product."
    end
  end

  identities do
    identity :unique_sku, [:sku]
    identity :unique_name, [:name]
  end
end
