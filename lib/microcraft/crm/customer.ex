defmodule Microcraft.CRM.Customer do
  require Ash.Resource.Preparation.Builtins

  use Ash.Resource,
    otp_app: :microcraft,
    domain: Microcraft.CRM,
    data_layer: AshPostgres.DataLayer

  postgres do
    table "crm_customers"
    repo Microcraft.Repo
  end

  actions do
    default_accept :*
    defaults [:read, :create, :update, :destroy]

    read :list do
      prepare build(sort: :first_name)

      pagination do
        required? false
        offset? true
        keyset? true
        countable true
      end
    end

    read :keyset do
      prepare build(sort: :first_name)
      pagination keyset?: true
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :type, :atom do
      allow_nil? false
      public? true
      constraints one_of: [:individual, :company]
    end

    attribute :first_name, :string do
      allow_nil? false
      public? true
      constraints min_length: 1
    end

    attribute :last_name, :string do
      allow_nil? false
      public? true
      constraints min_length: 1
    end

    attribute :email, :string do
      allow_nil? true
      public? true
      constraints match: ~r/@/
    end

    attribute :phone, :string do
      allow_nil? true
      public? true
      constraints max_length: 15
    end

    attribute :billing_address, Microcraft.CRM.Address do
      public? true
    end

    attribute :shipping_address, Microcraft.CRM.Address do
      public? true
    end

    timestamps()
  end

  relationships do
    has_many :orders, Microcraft.Orders.Order
  end

  calculations do
    calculate :full_name, :string, expr(first_name <> " " <> last_name)
  end

  aggregates do
    count :total_orders, :orders
    sum :total_orders_value, [:orders, :items], :cost
  end

  identities do
    identity :unique_phone, [:phone]
    identity :unique_email, [:email]
  end
end
