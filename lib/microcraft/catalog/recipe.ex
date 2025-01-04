defmodule Microcraft.Catalog.Recipe do
  @moduledoc false
  use Ash.Resource,
    otp_app: :microcraft,
    domain: Microcraft.Catalog,
    data_layer: AshPostgres.DataLayer

  postgres do
    table "catalog_recipes"
    repo Microcraft.Repo
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      primary? true
      accept [:instructions, :product_id]

      argument :components, {:array, :map}

      change manage_relationship(:components, type: :direct_control)
    end

    update :update do
      require_atomic? false
      accept [:instructions, :product_id]

      argument :components, {:array, :map}

      change manage_relationship(:components, type: :direct_control)
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

    has_many :components, Microcraft.Catalog.RecipeMaterial
  end

  aggregates do
    sum :cost, :components, :cost do
      description "The total cost of all materials in the recipe."
    end

    count :total_materials, :components do
      description "The total number of materials in the recipe."
    end
  end
end
