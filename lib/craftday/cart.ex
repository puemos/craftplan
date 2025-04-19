defmodule Craftday.Cart do
  @moduledoc """
  The Cart context - handles shopping cart operations.
  """

  alias Craftday.Cart.Item
  alias Craftday.Catalog

  @doc """
  Gets the cart from the session, or creates a new one.
  """
  def get_cart(nil), do: %{items: %{}, total_items: 0}
  def get_cart(cart), do: cart

  @doc """
  Adds an item to the cart.
  """
  def add_item(cart, product_id, quantity) when is_binary(quantity) do
    add_item(cart, product_id, String.to_integer(quantity))
  end

  def add_item(cart, product_id, quantity) when is_integer(quantity) and quantity > 0 do
    product = Catalog.get_product_by_id!(product_id)

    items =
      Map.update(
        cart.items,
        product_id,
        %Item{product: product, quantity: quantity},
        &%{&1 | quantity: &1.quantity + quantity}
      )

    total_items = Enum.reduce(items, 0, fn {_id, item}, acc -> acc + item.quantity end)

    %{items: items, total_items: total_items}
  end

  @doc """
  Updates the quantity of an item in the cart.
  """
  def update_item(cart, product_id, quantity) when is_binary(quantity) do
    update_item(cart, product_id, String.to_integer(quantity))
  end

  def update_item(cart, product_id, quantity) when is_integer(quantity) and quantity > 0 do
    items =
      Map.update!(cart.items, product_id, fn item ->
        %{item | quantity: quantity}
      end)

    total_items = Enum.reduce(items, 0, fn {_id, item}, acc -> acc + item.quantity end)

    %{items: items, total_items: total_items}
  end

  @doc """
  Removes an item from the cart.
  """
  def remove_item(cart, product_id) do
    items = Map.delete(cart.items, product_id)
    total_items = Enum.reduce(items, 0, fn {_id, item}, acc -> acc + item.quantity end)

    %{items: items, total_items: total_items}
  end

  @doc """
  Clears the cart.
  """
  def clear_cart(_cart) do
    %{items: %{}, total_items: 0}
  end
end
