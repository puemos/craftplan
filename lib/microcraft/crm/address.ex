defmodule Microcraft.CRM.Address do
  use Ash.Resource,
    data_layer: :embedded,
    embed_nil_values?: false

  actions do
    default_accept :*
    defaults [:read, :create, :update, :destroy]
  end

  validations do
    validate present([:street, :city, :country], at_least: 1)
  end

  attributes do
    attribute :street, :string, public?: true
    attribute :city, :string, public?: true
    attribute :state, :string, public?: true
    attribute :zip, :string, public?: true
    attribute :country, :string, public?: true
  end

  calculations do
    calculate :full_address,
              :string,
              concat([:street, :city, :state, :zip, :country], ", ")
  end
end
