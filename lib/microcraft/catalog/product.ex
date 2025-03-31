defmodule Microcraft.Catalog.Product do
  @moduledoc false
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
      default :draft
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

    calculate :allergens, :vector, Microcraft.Catalog.Product.Calculations.Allergens

    calculate :nutritional_facts,
              :vector,
              Microcraft.Catalog.Product.Calculations.NutritionalFacts
  end

  identities do
    identity :sku, [:sku]
    identity :name, [:name]
  end
end
