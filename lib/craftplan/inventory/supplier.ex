defmodule Craftplan.Inventory.Supplier do
  @moduledoc false
  use Ash.Resource,
    otp_app: :craftplan,
    domain: Craftplan.Inventory,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [AshJsonApi.Resource, AshGraphql.Resource]

  json_api do
    type "supplier"

    routes do
      base("/suppliers")
      get(:read)
      index :list
      post(:create)
      patch(:update)
    end
  end

  graphql do
    type :supplier

    queries do
      get(:get_supplier, :read)
      list(:list_suppliers, :list)
    end

    mutations do
      create :create_supplier, :create
      update :update_supplier, :update
    end
  end

  postgres do
    table "inventory_suppliers"
    repo Craftplan.Repo
  end

  actions do
    defaults [:read, :destroy]

    read :list do
      prepare build(sort: [name: :asc])
    end

    create :create do
      primary? true
      accept [:name, :contact_name, :contact_email, :contact_phone, :notes]
    end

    update :update do
      accept [:name, :contact_name, :contact_email, :contact_phone, :notes]
    end
  end

  policies do
    # API key scope check
    policy always() do
      authorize_if {Craftplan.Accounts.Checks.ApiScopeCheck, []}
    end

    policy action_type(:read) do
      authorize_if expr(^actor(:role) in [:staff, :admin])
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

    attribute :contact_name, :string do
      allow_nil? true
    end

    attribute :contact_email, :string do
      allow_nil? true
    end

    attribute :contact_phone, :string do
      allow_nil? true
    end

    attribute :notes, :string do
      allow_nil? true
      constraints max_length: 2000
    end

    timestamps()
  end
end
