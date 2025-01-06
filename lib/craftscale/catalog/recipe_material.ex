defmodule CraftScale.Catalog.RecipeMaterial do
  @moduledoc false
  use Ash.Resource,
    otp_app: :craftscale,
    domain: CraftScale.Catalog,
    data_layer: AshPostgres.DataLayer

  postgres do
    table "catalog_recipe_materials"
    repo CraftScale.Repo
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
    belongs_to :recipe, CraftScale.Catalog.Recipe do
      allow_nil? false
    end

    belongs_to :material, CraftScale.Inventory.Material do
      allow_nil? false
      domain CraftScale.Inventory
    end
  end

  calculations do
    calculate :cost, :decimal, expr(quantity * material.price) do
      description "The total cost of this recipe material (quantity * material price)."
    end
  end
end
