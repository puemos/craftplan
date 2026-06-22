defmodule Craftplan.Inventory.Material do
  @moduledoc false
  use Ash.Resource,
    otp_app: :craftplan,
    domain: Craftplan.Inventory,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [AshJsonApi.Resource, AshGraphql.Resource]

  alias Craftplan.Inventory.MaterialAllergen
  alias Craftplan.Inventory.MaterialNutritionalFact

  json_api do
    type "material"

    routes do
      base("/materials")
      get(:read)
      index :list
      post(:create)
      patch(:update)
    end
  end

  graphql do
    type :material

    queries do
      get(:get_material, :read)
      list(:list_materials, :list)
    end

    mutations do
      create :create_material, :create
      update :update_material, :update
      update :archive_material, :archive
      update :unarchive_material, :unarchive
    end
  end

  postgres do
    table "inventory_materials"
    repo Craftplan.Repo
  end

  actions do
    defaults [
      :read,
      :destroy,
      create: [
        :name,
        :sku,
        :external_sku,
        :unit,
        :price,
        :minimum_stock,
        :maximum_stock
      ]
    ]

    update :update do
      primary? true
      require_atomic? false

      accept [
        :name,
        :sku,
        :external_sku,
        :unit,
        :price,
        :minimum_stock,
        :maximum_stock
      ]

      change Craftplan.Inventory.Changes.StampPriceUpdatedAt
      change Craftplan.Inventory.Changes.RefreshAffectedBomRollups
    end

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

    update :archive do
      description "Mark a material as archived. Preserves all history; hides from default list."
      accept []
      change set_attribute(:archived_at, &DateTime.utc_now/0)
    end

    update :unarchive do
      description "Restore an archived material."
      accept []
      change set_attribute(:archived_at, nil)
    end

    read :list do
      argument :include_archived, :boolean do
        allow_nil? false
        default false
        description "Include archived materials in the result."
      end

      prepare build(sort: :name)

      filter expr(^arg(:include_archived) == true or is_nil(archived_at))

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

  policies do
    # Public reads (used for planner math, printouts, and exports); restrict writes
    # API key scope check
    policy always() do
      authorize_if {Craftplan.Accounts.Checks.ApiScopeCheck, []}
    end

    policy action_type(:read) do
      authorize_if always()
    end

    policy action_type([:create, :update, :destroy]) do
      authorize_if expr(^actor(:role) in [:staff, :admin])
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :name, :string do
      public? true
      allow_nil? false

      constraints min_length: 2,
                  max_length: 255,
                  match: ~r/^[\p{L}\p{N}\w\s\-\.・（）「」]+$/u
    end

    attribute :sku, :string do
      public? true
      allow_nil? false

      constraints min_length: 2,
                  max_length: 50
    end

    attribute :external_sku, :string do
      public? true
      allow_nil? true
      description "Supplier product code (e.g. IGF 34998) for invoice-to-material matching"

      constraints max_length: 50
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

    attribute :price_updated_at, :utc_datetime do
      public? true
      allow_nil? true
      description "When Material.price was last set. Auto-stamped when :price is in the changeset."
    end

    attribute :archived_at, :utc_datetime do
      public? true
      allow_nil? true
      description "When the material was archived. Nil means active."
    end

    timestamps()
  end

  relationships do
    has_many :movements, Craftplan.Inventory.Movement
    has_many :material_allergens, MaterialAllergen
    has_many :material_nutritional_facts, MaterialNutritionalFact
    # Recipes removed

    many_to_many :allergens, Craftplan.Inventory.Allergen, through: MaterialAllergen

    many_to_many :nutritional_facts, Craftplan.Inventory.NutritionalFact, through: MaterialNutritionalFact
  end

  aggregates do
    sum :current_stock, :movements, :quantity
  end

  identities do
    identity :name, [:name]
    identity :sku, [:sku]
    identity :external_sku, [:external_sku], nils_distinct?: true
  end
end
