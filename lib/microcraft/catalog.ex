defmodule CraftScale.Catalog do
  @moduledoc false
  use Ash.Domain

  resources do
    resource CraftScale.Catalog.Product do
      define :get_product_by_id, action: :read, get_by: [:id]
      define :get_product_by_sku, action: :read, get_by: [:sku]
      define :list_products, action: :list
      define :list_products_with_keyset, action: :keyset
    end

    resource CraftScale.Catalog.Recipe
    resource CraftScale.Catalog.RecipeMaterial
  end
end
