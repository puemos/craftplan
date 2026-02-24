defmodule Craftplan.Inventory.PurchaseOrderItem do
  @moduledoc false
  use Ash.Resource,
    otp_app: :craftplan,
    domain: Craftplan.Inventory,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [AshOban]

  postgres do
    table "inventory_purchase_order_items"
    repo Craftplan.Repo
  end

  oban do
    triggers do
      trigger :update_currency do
        action :change_currency
        worker_read_action(:list)
        queue(:default)
        worker_module_name(Craftplan.Inventory.PurchaseOrderItem.AshOban.Worker.Process)
        scheduler_module_name(Craftplan.Inventory.PurchaseOrderItem.AshOban.Scheduler.Process)
      end
    end

    domain Craftplan.System
  end

  actions do
    defaults [:read, :destroy]

    read :list do
      prepare build(sort: [inserted_at: :asc], load: [:material, :purchase_order])

      pagination do
        required? false
        offset? true
        keyset? true
        countable true
      end
    end

    read :open_for_material do
      argument :material_id, :uuid do
        allow_nil? false
      end

      prepare build(
                sort: [inserted_at: :asc],
                load: [
                  :material,
                  purchase_order: [:supplier]
                ],
                filter: expr(material_id == ^arg(:material_id) and purchase_order.status != :received)
              )
    end

    create :create do
      primary? true
      accept [:purchase_order_id, :material_id, :quantity, :unit_price]
    end

    update :update do
      accept [:quantity, :unit_price]
    end

    update :change_currency do
      require_atomic? false
      change Craftplan.Inventory.Changes.AssignCurrencyPO
    end
  end

  policies do
    bypass AshOban.Checks.AshObanInteraction do
      authorize_if always()
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

    attribute :quantity, :decimal do
      allow_nil? false
      default 0
    end

    attribute :unit_price, AshMoney.Types.Money do
      allow_nil? true
    end

    timestamps()
  end

  relationships do
    belongs_to :purchase_order, Craftplan.Inventory.PurchaseOrder do
      allow_nil? false
    end

    belongs_to :material, Craftplan.Inventory.Material do
      allow_nil? false
    end
  end
end
