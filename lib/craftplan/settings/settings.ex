defmodule Craftplan.Settings.Settings do
  @moduledoc false
  use Ash.Resource,
    otp_app: :craftplan,
    domain: Craftplan.Settings,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [AshJsonApi.Resource]

  alias Craftplan.Types.EncryptedBinary

  json_api do
    type "settings"

    routes do
      base("/settings")
      get(:get)
      patch(:update)
    end
  end

  postgres do
    table "settings"
    repo Craftplan.Repo
  end

  actions do
    default_accept :*

    defaults [:read, :update]

    create :init do
      accept []
    end

    read :get do
      get? true
    end
  end

  policies do
    # API key scope check
    policy always() do
      authorize_if {Craftplan.Accounts.Checks.ApiScopeCheck, []}
    end

    # Allow read of settings for everyone (used across site)
    policy action_type(:read) do
      authorize_if always()
    end

    # Allow init (bootstrap) without auth
    policy action(:init) do
      authorize_if always()
    end

    # Restrict updates/deletes to admin
    policy action_type([:update, :destroy]) do
      authorize_if expr(^actor(:role) in [:admin])
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :currency, Craftplan.Types.Currency do
      public? true
      allow_nil? false
      default :USD
    end

    # Tax configuration
    attribute :tax_mode, :atom do
      public? true
      allow_nil? false
      default :exclusive
      constraints one_of: [:inclusive, :exclusive]
    end

    attribute :tax_rate, :decimal do
      public? true
      allow_nil? false
      default 0
    end

    # Fulfillment configuration
    attribute :offers_pickup, :boolean do
      public? true
      allow_nil? false
      default true
    end

    attribute :offers_delivery, :boolean do
      public? true
      allow_nil? false
      default true
    end

    attribute :lead_time_days, :integer do
      public? true
      allow_nil? false
      default 0
      constraints min: 0
    end

    attribute :daily_capacity, :integer do
      public? true
      allow_nil? false
      default 0
      description "Max orders per day (0 = unlimited)"
      constraints min: 0
    end

    attribute :shipping_flat, AshMoney.Types.Money do
      public? true
      allow_nil? false
      default Money.new!(0, :USD)
    end

    attribute :labor_hourly_rate, AshMoney.Types.Money do
      public? true
      allow_nil? false
      default Money.new!(0, :USD)
      description "Default hourly labor rate used for cost calculations."
    end

    attribute :labor_overhead_percent, :decimal do
      public? true
      allow_nil? false
      default 0
      constraints min: 0
      description "Applied as a percentage (0.0-1.0) of material + labor costs."
    end

    attribute :retail_markup_mode, :atom do
      public? true
      allow_nil? false
      default :percent
      constraints one_of: [:percent, :fixed]
    end

    attribute :retail_markup_value, :decimal do
      public? true
      allow_nil? false
      default 0
      constraints min: 0
    end

    attribute :wholesale_markup_mode, :atom do
      public? true
      allow_nil? false
      default :percent
      constraints one_of: [:percent, :fixed]
    end

    attribute :wholesale_markup_value, :decimal do
      public? true
      allow_nil? false
      default 0
      constraints min: 0
    end

    # Email sender
    attribute :email_from_name, :string do
      public? true
      allow_nil? false
      default "Craftplan"
    end

    attribute :email_from_address, :string do
      public? true
      allow_nil? false
      default "noreply@craftplan.app"
    end

    # Email provider
    attribute :email_provider, :atom do
      public? true
      allow_nil? false
      default :smtp
      constraints one_of: [:smtp, :sendgrid, :mailgun, :postmark, :brevo, :amazon_ses]
    end

    attribute :email_api_key, EncryptedBinary do
      public? true
      sensitive? true
    end

    attribute :email_api_secret, EncryptedBinary do
      public? true
      sensitive? true
    end

    attribute :email_api_domain, :string do
      public? true
    end

    attribute :email_api_region, :string do
      public? true
      default "us-east-1"
    end

    # SMTP configuration
    attribute :smtp_host, :string do
      public? true
    end

    attribute :smtp_port, :integer do
      public? true
      default 587
    end

    attribute :smtp_username, :string do
      public? true
    end

    attribute :smtp_password, :string do
      public? true
      sensitive? true
    end

    attribute :smtp_tls, :atom do
      public? true
      default :if_available
      constraints one_of: [:if_available, :always, :never]
    end

    # Inventory forecasting configuration
    attribute :forecast_lookback_days, :integer do
      public? true
      allow_nil? false
      default 42
      constraints min: 7, max: 365
      description "Number of past days to analyze for historical usage patterns."
    end

    attribute :forecast_actual_weight, :decimal do
      public? true
      allow_nil? false
      default Decimal.new("0.6")
      constraints min: 0, max: 1

      description "Weight given to actual historical usage (0-1). Remainder goes to planned usage."
    end

    attribute :forecast_planned_weight, :decimal do
      public? true
      allow_nil? false
      default Decimal.new("0.4")
      constraints min: 0, max: 1

      description "Weight given to planned/forecasted usage (0-1). Should sum to 1 with actual weight."
    end

    attribute :forecast_min_samples, :integer do
      public? true
      allow_nil? false
      default 10
      constraints min: 3, max: 100

      description "Minimum data points required before calculating demand variability statistically."
    end

    attribute :forecast_default_service_level, :decimal do
      public? true
      allow_nil? false
      default Decimal.new("0.95")
      constraints min: Decimal.new("0.8"), max: Decimal.new("0.999")
      description "Target service level for safety stock calculations (e.g., 0.95 = 95%)."
    end

    attribute :forecast_default_horizon_days, :integer do
      public? true
      allow_nil? false
      default 14
      constraints min: 7, max: 90
      description "Default forecast horizon in days for the reorder planner."
    end
  end
end
