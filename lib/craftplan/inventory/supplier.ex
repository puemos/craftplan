defmodule Craftplan.Inventory.Supplier do
  @moduledoc false
  use Ash.Resource,
    otp_app: :craftplan,
    domain: Craftplan.Inventory,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

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

      accept [:organization_id, :name, :contact_name, :contact_email, :contact_phone, :notes]
    end

    update :update do
      primary? true

      accept [:organization_id, :name, :contact_name, :contact_email, :contact_phone, :notes]
    end
  end

  policies do
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

  relationships do
    belongs_to :organization, Craftplan.Organizations.Organization do
      attribute_type :uuid
      source_attribute :organization_id
      allow_nil? true
    end
  end
end
