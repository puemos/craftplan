defmodule Microcraft.Inventory.Material do
  @moduledoc false
  use Ash.Resource,
    otp_app: :microcraft,
    domain: Microcraft.Inventory,
    data_layer: AshPostgres.DataLayer

  alias Microcraft.Inventory.MaterialAllergen
  alias Microcraft.Inventory.MaterialNutritionalFact

  postgres do
    table "inventory_materials"
    repo Microcraft.Repo
  end

  actions do
    defaults [
      :read,
      :destroy,
      create: [
        :name,
        :sku,
        :unit,
        :price,
        :minimum_stock,
        :maximum_stock
      ],
      update: [
        :name,
        :sku,
        :unit,
        :price,
        :minimum_stock,
        :maximum_stock
      ]
    ]

    update :update_allergens do
      require_atomic? false

      argument :material_allergens, {:array, :map}

      change manage_relationship(:material_allergens, type: :direct_control)
    end

    update :update_nutritional_facts do
      require_atomic? false

      argument :material_nutritional_facts, {:array, :map}

      change manage_relationship(:material_nutritional_facts, type: :direct_control)
    end

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
      public? true
      allow_nil? false

      constraints min_length: 2,
                  max_length: 50,
                  match: ~r/^[\w\s\-\.]+$/
    end

    attribute :sku, :string do
      public? true
      allow_nil? false

      constraints min_length: 2,
                  max_length: 50
    end

    attribute :unit, :unit do
      public? true
      allow_nil? false
    end

    attribute :price, :decimal do
      public? true
      allow_nil? false
    end

    attribute :minimum_stock, :decimal do
      public? true
      constraints min: 0
    end

    attribute :maximum_stock, :decimal do
      public? true
      constraints min: 0
    end

    timestamps()
  end

  relationships do
    has_many :movements, Microcraft.Inventory.Movement
    has_many :material_allergens, MaterialAllergen
    has_many :material_nutritional_facts, MaterialNutritionalFact
    many_to_many :recipes, Microcraft.Catalog.Recipe, through: Microcraft.Catalog.RecipeMaterial

    many_to_many :allergens, Microcraft.Inventory.Allergen, through: MaterialAllergen

    many_to_many :nutritional_facts, Microcraft.Inventory.NutritionalFact, through: MaterialNutritionalFact
  end

  aggregates do
    sum :current_stock, :movements, :quantity
  end

  identities do
    identity :name, [:name]
    identity :sku, [:sku]
  end
end
