defmodule Craftplan.Cart do
  @moduledoc """
  The Cart domain - handles shopping cart operations.
  """
  use Ash.Domain

  resources do
    resource Craftplan.Cart.Cart do
      define :get_cart_by_id, action: :read, get_by: [:id]
      define :list_carts, action: :list
      define :create_cart, action: :create
      define :update_cart, action: :update
      define :delete_cart, action: :destroy
    end

    resource Craftplan.Cart.CartItem do
      define :get_cart_item_by_id, action: :read, get_by: [:id]
      define :list_cart_items, action: :read
      define :create_cart_item, action: :create
      define :update_cart_item, action: :update
      define :delete_cart_item, action: :destroy
    end
  end
end
