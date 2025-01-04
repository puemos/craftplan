defmodule Microcraft.Inventory.Material do
  @moduledoc false
  use Ash.Resource,
    otp_app: :microcraft,
    domain: Microcraft.Catalog,
    data_layer: AshPostgres.DataLayer

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

    has_many :recipe_materials, Microcraft.Catalog.RecipeMaterial do
      domain Microcraft.Catalog
    end
  end

  aggregates do
    sum :current_stock, :movements, :quantity
  end

  identities do
    identity :unique_name, [:name]
    identity :unique_sku, [:sku]
  end
end
