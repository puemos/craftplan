defmodule CraftScale.Orders.Order do
  @moduledoc false
  use Ash.Resource,
    otp_app: :craftscale,
    domain: CraftScale.Orders,
    data_layer: AshPostgres.DataLayer

  postgres do
    table "orders_orders"
    repo CraftScale.Repo
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      primary? true
      accept [:status, :customer_id, :delivery_date]

      argument :items, {:array, :map}

      change manage_relationship(:items, type: :direct_control)
    end

    update :update do
      require_atomic? false
      accept [:status, :customer_id, :delivery_date]

      argument :items, {:array, :map}

      change manage_relationship(:items, type: :direct_control)
    end

    read :list do
      prepare build(sort: [delivery_date: :desc])

      pagination do
        required? false
        offset? true
        keyset? true
        countable true
      end
    end

    read :keyset do
      prepare build(sort: [delivery_date: :desc])
      pagination keyset?: true
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :delivery_date, :utc_datetime do
      allow_nil? false
    end

    attribute :status, CraftScale.Orders.Order.Types.Status do
      allow_nil? false
      default :pending
    end

    timestamps()
  end

  relationships do
    has_many :items, CraftScale.Orders.OrderItem

    belongs_to :customer, CraftScale.CRM.Customer do
      allow_nil? false
      domain CraftScale.CRM
    end
  end

  aggregates do
    count :total_items, :items
    sum :total_cost, :items, :cost
  end
end
