defmodule Craftplan.Catalog.LaborStep do
  @moduledoc false
  use Ash.Resource,
    otp_app: :craftplan,
    domain: Craftplan.Catalog,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshOban]

  alias AshMoney.Types.Money
  alias Craftplan.Catalog.Services.BOMRollup

  postgres do
    table "catalog_labor_steps"
    repo Craftplan.Repo
  end

  oban do
    triggers do
      trigger :update_currency do
        action :change_currency
        worker_read_action(:list)
        queue(:default)
        worker_module_name(Craftplan.Catalog.LaborStep.AshOban.Worker.Process)
        scheduler_module_name(Craftplan.Catalog.LaborStep.AshOban.Scheduler.Process)
      end
    end

    domain Craftplan.System
  end

  actions do
    defaults [:read, :destroy]

    read :list do
      pagination do
        required? false
        offset? true
        keyset? true
        countable true
      end
    end

    create :create do
      primary? true
      accept [:name, :sequence, :duration_minutes, :rate_override, :units_per_run, :notes]

      change after_action(fn changeset, result, _ctx ->
               bom_id = Map.get(result, :bom_id) || Map.get(changeset.data, :bom_id)

               BOMRollup.refresh_by_bom_id!(
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
      accept [:name, :sequence, :duration_minutes, :rate_override, :units_per_run, :notes]

      change after_action(fn changeset, result, _ctx ->
               bom_id = Map.get(result, :bom_id) || Map.get(changeset.data, :bom_id)

               BOMRollup.refresh_by_bom_id!(
                 bom_id,
                 actor: changeset.context[:actor],
                 authorize?: false
               )

               {:ok, result}
             end)
    end

    update :change_currency do
      accept []

      change Craftplan.Catalog.Changes.AssignCurrencyLS
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :name, :string do
      allow_nil? false
      constraints min_length: 1, allow_empty?: false
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

    attribute :rate_override, Money do
      allow_nil? true
    end

    attribute :units_per_run, :decimal do
      allow_nil? false
      default 1
      constraints min: 1
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
