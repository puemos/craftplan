defmodule Microcraft.CRM.Customer do
  use Ash.Resource,
    otp_app: :microcraft,
    domain: Microcraft.CRM,
    data_layer: AshPostgres.DataLayer

  postgres do
    table "crm_customers"
    repo Microcraft.Repo
  end

  actions do
    defaults [:read, :create, :update, :destroy]
  end

  attributes do
    uuid_primary_key :id

    attribute :type, :atom do
      allow_nil? false
      public? true
      constraints one_of: [:individual, :company]
    end

    attribute :name, :string do
      allow_nil? false
      public? true
      constraints min_length: 1
    end

    attribute :email, :string do
      allow_nil? true
      constraints match: ~r/@/
    end

    attribute :phone, :string do
      allow_nil? true
      constraints max_length: 15
    end

    attribute :address, Microcraft.CRM.Address do
      public? true
      constraints load: [:full_address]
    end

    timestamps()
  end

  relationships do
    has_many :orders, Microcraft.Orders.Order
  end
end
