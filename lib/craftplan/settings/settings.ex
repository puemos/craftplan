defmodule Craftplan.Settings.Settings do
  @moduledoc false
  use Ash.Resource,
    otp_app: :craftplan,
    domain: Craftplan.Settings,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

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

    attribute :shipping_flat, :decimal do
      public? true
      allow_nil? false
      default 0
    end

    attribute :labor_hourly_rate, :decimal do
      public? true
      allow_nil? false
      default 0
      constraints min: 0
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

    attribute :advanced_recipe_versioning, :boolean do
      public? true
      allow_nil? false
      default false

      description "Expose advanced recipe/BOM versioning controls (version switcher & inline history)."
    end
  end
end
