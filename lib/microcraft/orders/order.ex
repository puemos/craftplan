defmodule Microcraft.Orders.Order do
  @moduledoc false
  use Ash.Resource,
    otp_app: :microcraft,
    domain: Microcraft.Orders,
    data_layer: AshPostgres.DataLayer

  postgres do
    table "orders_orders"
    repo Microcraft.Repo
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

    attribute :reference, :string do
      writable? false

      default fn ->
        year = DateTime.utc_now().year |> Integer.to_string() |> String.pad_leading(4, "0")
        month = DateTime.utc_now().month |> Integer.to_string() |> String.pad_leading(2, "0")
        day = DateTime.utc_now().day |> Integer.to_string() |> String.pad_leading(2, "0")
        random = for _ <- 1..6, into: "", do: <<Enum.random(?A..?Z)>>
        "OR_#{year}_#{month}_#{day}_#{random}"
      end

      allow_nil? false
      generated? true

      constraints match: ~r/^OR_\d{4}_\d{2}_\d{2}_[A-Z]{6}$/,
                  allow_empty?: false
    end

    attribute :delivery_date, :utc_datetime do
      allow_nil? false
    end

    attribute :status, Microcraft.Orders.Order.Types.Status do
      allow_nil? false
      default :created
    end

    timestamps()
  end

  relationships do
    has_many :items, Microcraft.Orders.OrderItem

    belongs_to :customer, Microcraft.CRM.Customer do
      allow_nil? false
      domain Microcraft.CRM
    end
  end

  aggregates do
    count :total_items, :items
    sum :total_cost, :items, :cost
  end

  identities do
    identity :reference, [:reference]
  end
end
