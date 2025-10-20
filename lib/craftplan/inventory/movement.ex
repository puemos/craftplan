defmodule Craftplan.Inventory.Movement do
  @moduledoc false
  use Ash.Resource,
    otp_app: :craftplan,
    domain: Craftplan.Inventory,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table "inventory_movements"
    repo Craftplan.Repo
  end

  actions do
    defaults [:read, :destroy]

    create :adjust_stock do
      accept [:organization_id, :quantity, :reason, :material_id]

      change set_attribute(:occurred_at, &DateTime.utc_now/0)
    end
  end

  policies do
    policy action_type(:read) do
      authorize_if expr(^actor(:role) in [:staff, :admin])
    end

    policy action_type([:create, :update, :destroy]) do
      authorize_if expr(^actor(:role) in [:staff, :admin])
    end
  end

  multitenancy do
    strategy :attribute
    attribute :organization_id
    global? true
  end

  attributes do
    uuid_primary_key :id

    attribute :organization_id, :uuid do
      allow_nil? true
      public? true
    end

    attribute :quantity, :decimal do
      allow_nil? false
    end

    attribute :reason, :string do
      allow_nil? true
      constraints max_length: 255
    end

    attribute :occurred_at, :utc_datetime do
      allow_nil? false
    end

    timestamps()
  end

  relationships do
    belongs_to :organization, Craftplan.Organizations.Organization do
      attribute_type :uuid
      source_attribute :organization_id
      allow_nil? true
    end

    belongs_to :material, Craftplan.Inventory.Material do
      allow_nil? false
    end
  end
end
