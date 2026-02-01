defmodule Craftplan.Catalog do
  @moduledoc false
  use Ash.Domain,
    extensions: [AshJsonApi.Domain, AshGraphql.Domain]

  json_api do
    prefix "/api/json"
  end

  graphql do
  end

  @type product_id :: integer()

  resources do
    resource Craftplan.Catalog.Product do
      define :get_product_by_id, action: :read, get_by: [:id]
      define :get_product_by_sku, action: :read, get_by: [:sku]
      define :list_products, action: :list
      define :list_products_with_keyset, action: :keyset
      define :destroy_product, action: :destroy
      define :update_product, action: :update
    end

    resource Craftplan.Catalog.BOM do
      define :list_boms_for_product, action: :list_for_product
      define :get_active_bom_for_product, action: :get_active
      define :create_bom, action: :create
      define :update_bom, action: :update
    end

    resource Craftplan.Catalog.BOMRollup
    resource Craftplan.Catalog.BOMComponent
    resource Craftplan.Catalog.LaborStep
    # Recipes removed (BOM-only)
  end
end
