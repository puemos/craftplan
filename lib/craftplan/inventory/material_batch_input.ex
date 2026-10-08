defmodule Craftplan.Inventory.MaterialBatchInput do
  @moduledoc false
  use Ash.Resource,
    otp_app: :craftplan,
    domain: Craftplan.Inventory,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table "inventory_material_batch_inputs"
    repo Craftplan.Repo
  end

  actions do
    defaults [:read, create: [:material_batch_id, :lot_id, :quantity, :unit_cost]]
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
    attribute :quantity, :decimal, allow_nil?: false, constraints: [min: "0.000001"]
    attribute :unit_cost, :decimal, allow_nil?: false
    timestamps()
  end

  relationships do
    belongs_to :material_batch, Craftplan.Inventory.MaterialBatch, allow_nil?: false
    belongs_to :lot, Craftplan.Inventory.Lot, allow_nil?: false
  end

  identities do
    identity :batch_lot, [:material_batch_id, :lot_id]
  end
end
