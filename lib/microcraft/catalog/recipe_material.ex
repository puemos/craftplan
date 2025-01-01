defmodule Microcraft.Catalog.RecipeMaterial do
  use Ash.Resource,
    otp_app: :microcraft,
    domain: Microcraft.Catalog,
    data_layer: AshPostgres.DataLayer

  postgres do
    table "catalog_recipe_materials"
    repo Microcraft.Repo
  end

  actions do
    defaults [:read, :destroy, update: [:quantity]]

    create :create do
      primary? true
      accept [:quantity, :material_id]
    end
  end

  attributes do
    uuid_primary_key :id
    attribute :quantity, :decimal, allow_nil?: false

    timestamps()
  end

  relationships do
    belongs_to :recipe, Microcraft.Catalog.Recipe do
      allow_nil? false
    end

    belongs_to :material, Microcraft.Inventory.Material do
      allow_nil? false
      domain Microcraft.Inventory
    end
  end

  calculations do
    calculate :cost, :decimal, expr(quantity * material.price) do
      description "The total cost of this recipe material (quantity * material price)."
    end
  end
end
