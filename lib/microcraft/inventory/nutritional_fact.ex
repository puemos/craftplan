defmodule Microcraft.Inventory.NutritionalFact do
  @moduledoc false
  use Ash.Resource,
    data_layer: :embedded,
    embed_nil_values?: false

  actions do
    default_accept :*
    defaults [:read, :create, :update, :destroy]
  end

  attributes do
    attribute :name, :string, public?: true
    attribute :amount, :decimal, public?: true

    attribute :unit, :unit do
      public? true
      allow_nil? false
    end
  end
end
