defmodule Microcraft.Inventory do
  use Ash.Domain

  resources do
    resource Microcraft.Inventory.Material do
      define :get_material_by_id, action: :read, get_by: [:id]
      define :get_material_by_sku, action: :read, get_by: [:sku]
      define :list_materials, action: :list
      define :list_materials_with_keyset, action: :keyset
    end

    resource Microcraft.Inventory.Movement do
      define :adjust_stock, action: :adjust_stock
    end
  end
end
