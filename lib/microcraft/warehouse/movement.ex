defmodule Microcraft.Warehouse.Movement do
  use Ash.Resource,
    otp_app: :microcraft,
    domain: Microcraft.Warehouse,
    data_layer: AshPostgres.DataLayer

  postgres do
    table "Warehouse_movements"
    repo Microcraft.Repo
  end

  actions do
    defaults [:read, :destroy]

    create :adjust_stock do
      accept [:quantity, :reason, :material_id]

      change set_attribute(:occurred_at, &DateTime.utc_now/0)
    end
  end

  attributes do
    uuid_primary_key :id

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
    belongs_to :material, Microcraft.Warehouse.Material do
      allow_nil? false
    end
  end
end
