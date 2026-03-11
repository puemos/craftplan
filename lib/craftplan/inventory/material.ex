defmodule Craftplan.Inventory.Material do
  @moduledoc false
  use Ash.Resource,
    otp_app: :craftplan,
    domain: Craftplan.Inventory,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [AshJsonApi.Resource, AshGraphql.Resource, AshOban]

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
    end
  end

  postgres do
    table "inventory_materials"
    repo Craftplan.Repo
  end

  oban do
    triggers do
      trigger :update_currency do
        action :change_currency
        worker_read_action(:list)
        queue(:default)
        worker_module_name(Craftplan.Inventory.Material.AshOban.Worker.Process)
        scheduler_module_name(Craftplan.Inventory.Material.AshOban.Scheduler.Process)
      end
    end

    domain Craftplan.System
  end

  actions do
    defaults [
      :destroy,
      create: [
        :name,
        :sku,
        :unit,
        :price,
        :minimum_stock,
        :maximum_stock
      ]
    ]

    read :read do
      primary? true
      prepare build(load: [:location])

      pagination do
        required? false
        offset? true
        keyset? true
        countable true
      end
    end

    update :update do
      primary? true
      require_atomic? false

      accept [
        :name,
        :sku,
        :unit,
        :price,
        :minimum_stock,
        :maximum_stock,
        :location_id
      ]

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

    update :change_currency do
      require_atomic? false

      change Craftplan.Inventory.Changes.AssignCurrencyMaterial
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

  policies do
    bypass AshOban.Checks.AshObanInteraction do
      authorize_if always()
    end

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

    attribute :price, AshMoney.Types.Money do
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
    belongs_to :location, Craftplan.Inventory.Location
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
  end
end
