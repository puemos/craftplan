defmodule Craftday.Settings.Settings do
  @moduledoc false
  use Ash.Resource,
    otp_app: :craftday,
    domain: Craftday.Settings,
    data_layer: AshPostgres.DataLayer

  postgres do
    table "settings"
    repo Craftday.Repo
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

  attributes do
    uuid_primary_key :id

    attribute :currency, Craftday.Types.Currency do
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
  end
end
