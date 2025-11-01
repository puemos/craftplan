defmodule Craftplan.Catalog.LaborStep do
  @moduledoc false
  use Ash.Resource,
    otp_app: :craftplan,
    domain: Craftplan.Catalog,
    data_layer: AshPostgres.DataLayer

  postgres do
    table "catalog_labor_steps"
    repo Craftplan.Repo
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      primary? true
      accept [:name, :sequence, :duration_minutes, :rate_override, :notes]
    end

    update :update do
      accept [:name, :sequence, :duration_minutes, :rate_override, :notes]
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :name, :string do
      allow_nil? false
    end

    attribute :sequence, :integer do
      allow_nil? false
      default 0
      constraints min: 0
    end

    attribute :duration_minutes, :decimal do
      allow_nil? false
      default 0
      constraints min: 0
    end

    attribute :rate_override, :decimal do
      allow_nil? true
    end

    attribute :notes, :string do
      allow_nil? true
    end

    timestamps()
  end

  relationships do
    belongs_to :bom, Craftplan.Catalog.BOM do
      allow_nil? false
    end
  end
end
