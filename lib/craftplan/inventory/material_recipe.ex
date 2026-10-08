defmodule Craftplan.Inventory.MaterialRecipe do
  @moduledoc false
  use Ash.Resource,
    otp_app: :craftplan,
    domain: Craftplan.Inventory,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  alias Craftplan.Inventory.Material

  postgres do
    table "inventory_material_recipes"
    repo Craftplan.Repo
  end

  actions do
    defaults [:read]

    create :create do
      accept [:material_id, :yield_quantity, :components, :notes]
      touches_resources [Material]
      change Craftplan.Inventory.Changes.PrepareMaterialRecipe
    end
  end

  policies do
    policy always() do
      authorize_if {Craftplan.Accounts.Checks.ApiScopeCheck, []}
    end

    policy action_type(:read) do
      authorize_if expr(^actor(:role) in [:staff, :admin])
    end

    policy action_type([:create, :update, :destroy]) do
      authorize_if expr(^actor(:role) in [:staff, :admin])
    end
  end

  attributes do
    uuid_primary_key :id
    attribute :version, :integer, allow_nil?: false, writable?: false
    attribute :yield_quantity, :decimal, allow_nil?: false, constraints: [min: "0.000001"]
    attribute :components, {:array, :map}, allow_nil?: false, default: []
    attribute :notes, :string, constraints: [max_length: 2000]
    timestamps()
  end

  relationships do
    belongs_to :material, Material, allow_nil?: false
  end

  identities do
    identity :material_version, [:material_id, :version]
  end
end
