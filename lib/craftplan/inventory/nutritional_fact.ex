defmodule Craftplan.Inventory.NutritionalFact do
  @moduledoc false
  use Ash.Resource,
    otp_app: :craftplan,
    domain: Craftplan.Inventory,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  alias Craftplan.Inventory.Changes.SetNutritionalFactMetadata

  postgres do
    table "inventory_nutritional_facts"
    repo Craftplan.Repo
  end

  actions do
    defaults [:read]

    create :create do
      primary? true

      accept [
        :name,
        :key,
        :default_unit,
        :parent_key,
        :sort_order,
        :eu_required,
        :system
      ]

      change SetNutritionalFactMetadata
    end

    update :update do
      primary? true
      require_atomic? false

      accept [
        :name,
        :key,
        :default_unit,
        :parent_key,
        :sort_order,
        :eu_required,
        :system
      ]

      change SetNutritionalFactMetadata
    end

    destroy :destroy do
      primary? true
      require_atomic? false

      change Craftplan.Inventory.Changes.ProtectSystemNutritionalFact
    end

    read :list do
      prepare build(sort: [:sort_order, :name])

      pagination do
        required? false
        offset? true
        keyset? true
        countable true
      end
    end

    read :keyset do
      prepare build(sort: [:sort_order, :name])
      pagination keyset?: true
    end
  end

  policies do
    # Public read (displayed on nutrition labels and exports); writes restricted
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
      constraints min_length: 1, match: ~r/^[\p{L}\p{N}\w\s\-\.\(\)&・（）「」]+$/u
    end

    attribute :key, :string do
      public? true
      allow_nil? false
      constraints min_length: 1, match: ~r/^[\p{L}\p{N}_:\-]+$/u
    end

    attribute :default_unit, :unit do
      public? true
      allow_nil? false
      default :gram
    end

    attribute :parent_key, :string do
      public? true
    end

    attribute :sort_order, :integer do
      public? true
      allow_nil? false
      default 1000
      constraints min: 0
    end

    attribute :eu_required, :boolean do
      public? true
      allow_nil? false
      default false
    end

    attribute :system, :boolean do
      public? true
      allow_nil? false
      default false
    end

    timestamps()
  end

  identities do
    identity :key, [:key]
    identity :name, [:name]
  end
end
