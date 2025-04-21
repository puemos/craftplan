defmodule Craftday.Inventory.MaterialAllergen do
  @moduledoc false
  use Ash.Resource,
    otp_app: :craftday,
    domain: Craftday.Inventory,
    data_layer: AshPostgres.DataLayer

  postgres do
    table "inventory_material_allergen"
    repo Craftday.Repo
  end

  actions do
    defaults [:read, :destroy, update: :*]

    create :create do
      primary? true
      accept [:allergen_id, :material_id]
    end
  end

  relationships do
    belongs_to :material, Craftday.Inventory.Material, primary_key?: true, allow_nil?: false
    belongs_to :allergen, Craftday.Inventory.Allergen, primary_key?: true, allow_nil?: false
  end
end
