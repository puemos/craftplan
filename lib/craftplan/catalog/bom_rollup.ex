defmodule Craftplan.Catalog.BOMRollup do
  @moduledoc false
  use Ash.Resource,
    otp_app: :craftplan,
    domain: Craftplan.Catalog,
    data_layer: AshPostgres.DataLayer

  postgres do
    table "catalog_bom_rollups"
    repo Craftplan.Repo
  end

  actions do
    defaults [:read]

    create :create do
      primary? true
      accept [:bom_id, :product_id, :material_cost, :labor_cost, :overhead_cost, :unit_cost]
    end

    update :update do
      accept [:material_cost, :labor_cost, :overhead_cost, :unit_cost]
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :material_cost, :decimal do
      allow_nil? false
      default 0
    end

    attribute :labor_cost, :decimal do
      allow_nil? false
      default 0
    end

    attribute :overhead_cost, :decimal do
      allow_nil? false
      default 0
    end

    attribute :unit_cost, :decimal do
      allow_nil? false
      default 0
    end

    timestamps()
  end

  relationships do
    belongs_to :bom, Craftplan.Catalog.BOM do
      allow_nil? false
    end

    belongs_to :product, Craftplan.Catalog.Product do
      allow_nil? false
    end
  end

  identities do
    identity :unique_bom, [:bom_id]
  end
end
