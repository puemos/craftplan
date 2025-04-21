defmodule Craftday.Inventory.MaterialNutritionalFact do
  @moduledoc false
  use Ash.Resource,
    otp_app: :craftday,
    domain: Craftday.Inventory,
    data_layer: AshPostgres.DataLayer

  postgres do
    table "inventory_material_nutritional_fact"
    repo Craftday.Repo
  end

  actions do
    defaults [:read, :destroy, update: :*]

    create :create do
      primary? true
      accept [:nutritional_fact_id, :material_id, :amount, :unit]
    end
  end

  attributes do
    attribute :amount, :decimal do
      public? true
      allow_nil? false
    end

    attribute :unit, :unit do
      public? true
      allow_nil? false
    end
  end

  relationships do
    belongs_to :material, Craftday.Inventory.Material, primary_key?: true, allow_nil?: false

    belongs_to :nutritional_fact, Craftday.Inventory.NutritionalFact,
      primary_key?: true,
      allow_nil?: false
  end
end
