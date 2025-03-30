defmodule Microcraft.Inventory.NutritionalFact do
  @moduledoc false
  use Ash.Resource,
    otp_app: :microcraft,
    domain: Microcraft.Inventory,
    data_layer: AshPostgres.DataLayer

  postgres do
    table "inventory_nutritional_facts"
    repo Microcraft.Repo
  end

  actions do
    defaults [:read, :destroy, create: [:name], update: [:name]]

    read :list do
      prepare build(sort: :name)

      pagination do
        required? false
        offset? true
        keyset? true
        countable true
      end
    end

    read :keyset do
      prepare build(sort: :name)
      pagination keyset?: true
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :name, :string do
      public? true
      allow_nil? false
    end

    timestamps()
  end

  identities do
    identity :name, [:name]
  end
end
