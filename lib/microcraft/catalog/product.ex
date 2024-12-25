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
    defaults [:read, :destroy, create: [:name, :status, :price], update: [:name, :status, :price]]
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

    attribute :status, :product_status do
      allow_nil? false
      public? true
      default :idea
    end

    attribute :price, :decimal do
      public? true
      allow_nil? false
    end

    timestamps()
  end

  relationships do
    has_one :recipe, Microcraft.Catalog.Recipe
  end

  calculations do
    calculate :estimated_cost, :decimal, expr(recipe.cost) do
      description "The total cost of the product."
    end

    calculate :profit_margin, :decimal, expr((price - recipe.cost) / recipe.cost) do
      description "The total cost of the product."
    end
  end
end
