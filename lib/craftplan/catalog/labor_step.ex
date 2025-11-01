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
      change after_action(fn changeset, result, _ctx ->
        bom_id = Map.get(result, :bom_id) || Map.get(changeset.data, :bom_id)

        Craftplan.Catalog.Services.BOMRollup.refresh_by_bom_id!(
          bom_id,
          actor: changeset.context[:actor],
          authorize?: false
        )

        {:ok, result}
      end)
    end

    update :update do
      primary? true
      require_atomic? false
      accept [:name, :sequence, :duration_minutes, :rate_override, :notes]
      change after_action(fn changeset, result, _ctx ->
        bom_id = Map.get(result, :bom_id) || Map.get(changeset.data, :bom_id)

        Craftplan.Catalog.Services.BOMRollup.refresh_by_bom_id!(
          bom_id,
          actor: changeset.context[:actor],
          authorize?: false
        )

        {:ok, result}
      end)
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
