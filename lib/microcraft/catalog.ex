defmodule Microcraft.Catalog do
  @moduledoc false
  use Ash.Domain

  resources do
    resource Microcraft.Catalog.Product do
      define :get_product_by_id, action: :read, get_by: [:id]
      define :get_product_by_sku, action: :read, get_by: [:sku]
      define :list_products, action: :list
      define :list_products_with_keyset, action: :keyset
    end

    resource Microcraft.Catalog.Recipe
    resource Microcraft.Catalog.RecipeMaterial
    resource Microcraft.Inventory.Material
  end
end
