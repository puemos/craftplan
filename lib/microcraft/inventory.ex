defmodule CraftScale.Inventory do
  @moduledoc false
  use Ash.Domain

  resources do
    resource CraftScale.Inventory.Material do
      define :get_material_by_id, action: :read, get_by: [:id]
      define :get_material_by_sku, action: :read, get_by: [:sku]
      define :list_materials, action: :list
      define :list_materials_with_keyset, action: :keyset
    end

    resource CraftScale.Inventory.Movement do
      define :adjust_stock, action: :adjust_stock
    end

    resource CraftScale.Inventory.Allergen do
      define :list_allergens, action: :list
      define :list_allergens_with_keyset, action: :keyset
    end

    resource CraftScale.Inventory.MaterialAllergen
  end
end
