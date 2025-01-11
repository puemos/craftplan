defmodule Microcraft.Inventory.MaterialAllergen do
  @moduledoc false
  use Ash.Resource,
    otp_app: :microcraft,
    domain: Microcraft.Inventory,
    data_layer: AshPostgres.DataLayer

  postgres do
    table "inventory_material_allergen"
    repo Microcraft.Repo
  end

  actions do
    defaults [:read, :destroy, update: :*]

    create :create do
      primary? true
      accept [:allergen_id, :material_id]
    end
  end

  relationships do
    belongs_to :material, Microcraft.Inventory.Material, primary_key?: true, allow_nil?: false
    belongs_to :allergen, Microcraft.Inventory.Allergen, primary_key?: true, allow_nil?: false
  end
end
