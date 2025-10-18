defmodule Craftplan.Catalog.RecipeMaterial do
  @moduledoc false
  use Ash.Resource,
    otp_app: :craftplan,
    domain: Craftplan.Catalog,
    data_layer: AshPostgres.DataLayer

  postgres do
    table "catalog_recipe_materials"
    repo Craftplan.Repo
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
    belongs_to :recipe, Craftplan.Catalog.Recipe do
      allow_nil? false
    end

    belongs_to :material, Craftplan.Inventory.Material do
      allow_nil? false
      domain Craftplan.Inventory
    end
  end

  calculations do
    calculate :cost, :decimal, expr(quantity * material.price) do
      description "The total cost of this recipe material (quantity * material price)."
    end
  end
end
