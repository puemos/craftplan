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
  end
end
