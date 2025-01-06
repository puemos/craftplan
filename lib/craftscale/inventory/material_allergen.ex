defmodule CraftScale.Inventory.MaterialAllergen do
  @moduledoc false
  use Ash.Resource,
    otp_app: :craftscale,
    domain: CraftScale.Inventory,
    data_layer: AshPostgres.DataLayer

  postgres do
    table "inventory_material_allergen"
    repo CraftScale.Repo
  end

  actions do
    defaults [:read, :destroy, update: :*]

    create :create do
      primary? true
      accept [:allergen_id, :material_id]
    end
  end

  relationships do
    belongs_to :material, CraftScale.Inventory.Material, primary_key?: true, allow_nil?: false
    belongs_to :allergen, CraftScale.Inventory.Allergen, primary_key?: true, allow_nil?: false
  end
end
