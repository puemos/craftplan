defmodule Craftplan.Orders.Order do
  @moduledoc false
  use Ash.Resource,
    otp_app: :craftplan,
    domain: Craftplan.Orders,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  alias Craftplan.Orders.Changes.CalculateTotals
  alias Craftplan.Orders.Changes.ValidateConstraints
  alias Craftplan.Orders.Order.Types.PaymentStatus
  alias Craftplan.Orders.Order.Types.Status

  postgres do
    table "orders_orders"
    repo Craftplan.Repo
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      primary? true

      accept [
        :organization_id,
        :status,
        :customer_id,
        :delivery_date,
        :invoice_number,
        :invoice_status,
        :invoiced_at,
        :payment_method,
        :payment_status,
        :discount_type,
        :discount_value,
        :delivery_method
      ]

      argument :items, {:array, :map}

      change manage_relationship(:items, type: :direct_control)
      change {CalculateTotals, []}
      change {ValidateConstraints, []}
    end

    # Public, minimal create action for checkout
    create :public_create do
      accept [
        :organization_id,
        :customer_id,
        :delivery_date,
        :delivery_method,
        :shipping_total
      ]

      argument :items, {:array, :map}

      change manage_relationship(:items, type: :direct_control)
      change {CalculateTotals, []}
      change {ValidateConstraints, []}
    end

    update :update do
      require_atomic? false

      accept [
        :organization_id,
        :status,
        :customer_id,
        :delivery_date,
        :invoice_number,
        :invoice_status,
        :invoiced_at,
        :payment_method,
        :discount_type,
        :discount_value,
        :delivery_method,
        :tax_total,
        :shipping_total,
        :discount_total
      ]

      argument :items, {:array, :map}

      change manage_relationship(:items, type: :direct_control)
      change {CalculateTotals, []}
      change {ValidateConstraints, []}
    end

    read :list do
      prepare build(sort: [delivery_date: :asc], load: [:customer, items: [:product]])

      argument :status, {:array, :atom} do
        allow_nil? true
        default nil

        constraints items: [
                      one_of: Status.values()
                    ]
      end

      argument :payment_status, {:array, :atom} do
        allow_nil? true
        default nil

        constraints items: [
                      one_of: PaymentStatus.values()
                    ]
      end

      argument :delivery_date_start, :utc_datetime do
        allow_nil? true
        default nil
      end

      argument :delivery_date_end, :utc_datetime do
        allow_nil? true
        default nil
      end

      argument :customer_name, :string do
        allow_nil? true
        default nil
      end

      argument :product_id, :uuid do
        allow_nil? true
        default nil
      end

      filter expr(is_nil(^arg(:status)) or status in ^arg(:status))
      filter expr(is_nil(^arg(:payment_status)) or payment_status in ^arg(:payment_status))

      filter expr(is_nil(^arg(:delivery_date_start)) or delivery_date >= ^arg(:delivery_date_start))

      filter expr(is_nil(^arg(:delivery_date_end)) or delivery_date <= ^arg(:delivery_date_end))

      filter expr(
               is_nil(^arg(:customer_name)) or
                 fragment("? ILIKE ?", customer.full_name, "%" <> ^arg(:customer_name) <> "%")
             )

      filter expr(is_nil(^arg(:product_id)) or exists(items, product_id == ^arg(:product_id)))

      pagination do
        required? false
        offset? true
        keyset? true
        countable true
      end
    end

    read :keyset do
      prepare build(sort: [delivery_date: :asc])
      pagination keyset?: true
    end

    # Public, minimal read for showing an order by reference
    read :public_show do
      argument :reference, :string, allow_nil?: false

      prepare build(
                load: [items: [product: [:name, :sku]]],
                filter: expr(reference == ^arg(:reference))
              )
    end

    # Narrow day-range read used for capacity checks
    read :for_day do
      argument :delivery_date_start, :utc_datetime, allow_nil?: false
      argument :delivery_date_end, :utc_datetime, allow_nil?: false

      prepare build(
                sort: [delivery_date: :asc],
                filter:
                  expr(
                    delivery_date >= ^arg(:delivery_date_start) and
                      delivery_date <= ^arg(:delivery_date_end)
                  )
              )
    end

    # Read action for inventory forecasting - loads orders with all necessary relationships
    read :for_forecast do
      argument :start_date, :date, allow_nil?: false
      argument :end_date, :date, allow_nil?: false

      prepare build(
                sort: [delivery_date: :asc],
                load: [items: [product: [recipe: [components: [material: :current_stock]]]]],
                filter:
                  expr(
                    fragment("DATE(?)", delivery_date) >= ^arg(:start_date) and
                      fragment("DATE(?)", delivery_date) <= ^arg(:end_date)
                  )
              )
    end
  end

  policies do
    # Public create for checkout (restricted action)
    bypass action(:public_create) do
      authorize_if always()
    end

    # Public read for day-range listing/count (capacity checks)
    bypass action(:for_day) do
      authorize_if always()
    end

    # Public read for order status by reference
    bypass action(:public_show) do
      authorize_if always()
    end

    # Staff/admin only for forecasting
    policy action(:for_forecast) do
      authorize_if expr(^actor(:role) in [:staff, :admin])
    end

    # Other reads/writes restricted to staff/admin
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

    attribute :currency, Craftplan.Types.Currency do
      allow_nil? false
      default :USD
    end

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

    # Invoicing / payments / discounts
    attribute :invoice_number, :string do
      allow_nil? true
    end

    attribute :invoice_status, :atom do
      allow_nil? false
      default :none
      constraints one_of: [:none, :issued, :paid]
    end

    attribute :invoiced_at, :utc_datetime do
      allow_nil? true
    end

    attribute :payment_method, :atom do
      allow_nil? true
      constraints one_of: [:cash, :card, :bank_transfer, :other]
    end

    attribute :discount_type, :atom do
      allow_nil? false
      default :none
      constraints one_of: [:none, :percent, :fixed]
    end

    attribute :discount_value, :decimal do
      allow_nil? false
      default 0
    end

    attribute :delivery_method, :atom do
      allow_nil? false
      default :delivery
      constraints one_of: [:pickup, :delivery]
    end

    attribute :status, Status do
      allow_nil? false
      default :unconfirmed
    end

    attribute :payment_status, PaymentStatus do
      allow_nil? false
      default :pending
    end

    # Monetary totals (persisted)
    attribute :subtotal, :decimal do
      allow_nil? false
      default 0
    end

    attribute :tax_total, :decimal do
      allow_nil? false
      default 0
    end

    attribute :shipping_total, :decimal do
      allow_nil? false
      default 0
    end

    attribute :discount_total, :decimal do
      allow_nil? false
      default 0
    end

    attribute :total, :decimal do
      allow_nil? false
      default 0
    end

    attribute :paid_at, :utc_datetime do
      allow_nil? true
    end

    timestamps()
  end

  relationships do
    belongs_to :organization, Craftplan.Organizations.Organization do
      attribute_type :uuid
      source_attribute :organization_id
      allow_nil? true
    end

    has_many :items, Craftplan.Orders.OrderItem

    belongs_to :customer, Craftplan.CRM.Customer do
      allow_nil? false
      domain Craftplan.CRM
    end
  end

  aggregates do
    count :total_items, :items
    sum :total_cost, :items, :cost
  end

  identities do
    identity :reference, [:organization_id, :reference]
  end
end
