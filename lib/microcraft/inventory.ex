defmodule Microcraft.Inventory do
  @moduledoc false
  use Ash.Domain

  resources do
    resource Microcraft.Inventory.Material do
      define :get_material_by_id, action: :read, get_by: [:id]
      define :get_material_by_sku, action: :read, get_by: [:sku]
      define :list_materials, action: :list
      define :list_materials_with_keyset, action: :keyset
      define :update_nutritional_facts, action: :update_nutritional_facts
    end

    resource Microcraft.Inventory.Movement do
      define :adjust_stock, action: :adjust_stock
    end

    resource Microcraft.Inventory.Allergen do
      define :get_allergen_by_id, action: :read, get_by: [:id]
      define :list_allergens, action: :list
      define :list_allergens_with_keyset, action: :keyset
    end

    resource Microcraft.Inventory.MaterialAllergen

    resource Microcraft.Inventory.NutritionalFact do
      define :get_nutritional_fact_by_id, action: :read, get_by: [:id]
      define :get_nutritional_fact_by_name, action: :read, get_by: [:name]
      define :list_nutritional_facts, action: :list
      define :list_nutritional_facts_with_keyset, action: :keyset
    end

    resource Microcraft.Inventory.MaterialNutritionalFact
  end
end
