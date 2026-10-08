defmodule Craftplan.Inventory.MaterialBatch do
  @moduledoc false
  use Ash.Resource,
    otp_app: :craftplan,
    domain: Craftplan.Inventory,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  alias Craftplan.Inventory.Lot
  alias Craftplan.Inventory.Material
  alias Craftplan.Inventory.MaterialBatchInput

  postgres do
    table "inventory_material_batches"
    repo Craftplan.Repo
  end

  actions do
    defaults [:read]

    create :produce do
      accept [:material_id, :planned_quantity, :actual_quantity, :lot_code, :expiry_date, :notes]
      argument :recipe_id, :uuid, allow_nil?: false
      argument :inputs, {:array, :map}, allow_nil?: false

      touches_resources [
        Material,
        Lot,
        Craftplan.Inventory.Movement,
        MaterialBatchInput
      ]

      change Craftplan.Inventory.Changes.ProduceMaterialBatch
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
    attribute :planned_quantity, :decimal, allow_nil?: false, constraints: [min: "0.000001"]
    attribute :actual_quantity, :decimal, allow_nil?: false, constraints: [min: "0.000001"]
    attribute :lot_code, :string, allow_nil?: false, constraints: [min_length: 2, max_length: 100]
    attribute :expiry_date, :date
    attribute :notes, :string, constraints: [max_length: 2000]
    attribute :recipe_snapshot, :map, allow_nil?: false, writable?: false
    attribute :total_cost, :decimal, allow_nil?: false, writable?: false
    attribute :completed_at, :utc_datetime, allow_nil?: false, writable?: false
    timestamps()
  end

  relationships do
    belongs_to :material, Material, allow_nil?: false
    belongs_to :output_lot, Lot, allow_nil?: false, writable?: false
    has_many :inputs, MaterialBatchInput
  end

  identities do
    identity :output_lot, [:output_lot_id]
    identity :lot_code, [:lot_code]
  end
end
