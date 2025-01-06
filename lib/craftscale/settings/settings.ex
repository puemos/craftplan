defmodule CraftScale.Settings.Settings do
  @moduledoc false
  use Ash.Resource,
    otp_app: :craftscale,
    domain: CraftScale.Settings,
    data_layer: AshPostgres.DataLayer

  postgres do
    table "settings"
    repo CraftScale.Repo
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

    attribute :currency, CraftScale.Types.Currency do
      public? true
      allow_nil? false
      default :USD
    end
  end
end
