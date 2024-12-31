defmodule Microcraft.Settings.Settings do
  use Ash.Resource,
    otp_app: :microcraft,
    domain: Microcraft.Settings,
    data_layer: AshPostgres.DataLayer

  postgres do
    table "settings"
    repo Microcraft.Repo
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

    attribute :currency, Microcraft.Types.Currency do
      public? true
      allow_nil? false
      default :USD
    end
  end
end
