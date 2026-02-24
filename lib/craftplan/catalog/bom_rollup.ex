defmodule Craftplan.Catalog.BOMRollup do
  @moduledoc false
  use Ash.Resource,
    otp_app: :craftplan,
    domain: Craftplan.Catalog,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshOban]

  postgres do
    table "catalog_bom_rollups"
    repo Craftplan.Repo
  end

  oban do
    triggers do
      trigger :update_currency do
        action :change_currency
        worker_read_action(:list)
        queue(:default)
        worker_module_name(Craftplan.Catalog.BOMRollup.AshOban.Worker.Process)
        scheduler_module_name(Craftplan.Catalog.BOMRollup.AshOban.Scheduler.Process)
      end
    end

    domain Craftplan.Catalog.BOMRollup
  end

  actions do
    defaults [:read]

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

      accept [
        :bom_id,
        :product_id,
        :material_cost,
        :labor_cost,
        :overhead_cost,
        :unit_cost,
        :components_map
      ]
    end

    update :update do
      accept [:material_cost, :labor_cost, :overhead_cost, :unit_cost, :components_map]
    end

    update :change_currency do
      accept []

      change Craftplan.Catalog.Changes.AssignCurrencyBOM
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :material_cost, AshMoney.Types.Money do
      allow_nil? false
      default Money.new!(0, :EUR)
    end

    attribute :labor_cost, AshMoney.Types.Money do
      allow_nil? false
      default Money.new!(0, :EUR)
    end

    attribute :overhead_cost, AshMoney.Types.Money do
      allow_nil? false
      default Money.new!(0, :EUR)
    end

    attribute :unit_cost, AshMoney.Types.Money do
      allow_nil? false
      default Money.new!(0, :EUR)
    end

    # Flattened materials used per unit (JSONB map: material_id => quantity as string)
    attribute :components_map, :map do
      allow_nil? false
      default %{}
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
