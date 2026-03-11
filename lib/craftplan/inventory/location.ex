defmodule Craftplan.Inventory.Location do
  @moduledoc false
  use Ash.Resource,
    otp_app: :craftplan,
    domain: Craftplan.Inventory,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [AshJsonApi.Resource, AshGraphql.Resource]

  json_api do
    type "location"

    routes do
      base("/inventory_locations")
      get(:read)
      index :read
    end
  end

  graphql do
    type :location

    queries do
      get(:get_location, :read)
      list(:list_locations, :read)
    end
  end

  postgres do
    table "inventory_locations"
    repo Craftplan.Repo

    custom_indexes do
    end
  end

  actions do
    defaults [
      :read,
      :destroy,
      create: [:name],
      update: [:name]
    ]
  end

  policies do
    # API key scope check
    policy always() do
      authorize_if {Craftplan.Accounts.Checks.ApiScopeCheck, []}
    end

    policy action_type(:read) do
      authorize_if always()
    end

    policy action_type([:create, :update, :destroy]) do
      authorize_if expr(^actor(:role) in [:staff, :admin])
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :name, :string do
      allow_nil? false
    end

    attribute :description, :string do
      allow_nil? true
    end

    timestamps()
  end

  relationships do
    has_many :materials, Craftplan.Inventory.Material
  end

  aggregates do
  end
end
