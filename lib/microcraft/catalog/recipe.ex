defmodule Microcraft.Catalog.Recipe do
  use Ash.Resource,
    otp_app: :microcraft,
    domain: Microcraft.Catalog,
    data_layer: AshPostgres.DataLayer

  postgres do
    table "catalog_recipes"
    repo Microcraft.Repo
  end

  actions do
    defaults [:read, :destroy, update: :*]

    create :create do
      primary? true
      accept [:instructions, :product_id]
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :instructions, :string do
      public? true
    end

    timestamps()
  end

  relationships do
    belongs_to :product, Microcraft.Catalog.Product do
      allow_nil? false
    end

    has_many :recipe_materials, Microcraft.Catalog.RecipeMaterial

    many_to_many :materials, Microcraft.Warehouse.Material,
      through: Microcraft.Catalog.RecipeMaterial
  end

  aggregates do
    sum :cost, :recipe_materials, :cost do
      description "The total cost of all materials in the recipe."
    end

    count :total_materials, :recipe_materials do
      description "The total number of materials in the recipe."
    end
  end
end
