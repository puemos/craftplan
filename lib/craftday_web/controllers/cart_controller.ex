defmodule CraftdayWeb.CartController do
  use CraftdayWeb, :controller

  alias Craftday.Cart

  def add(conn, %{"product_id" => product_id, "quantity" => quantity}) do
    cart = get_session(conn, :cart) || %{items: %{}, total_items: 0}
    updated_cart = Cart.add_item(cart, product_id, quantity)

    conn
    |> put_session(:cart, updated_cart)
    |> redirect(to: ~p"/cart")
  end

  def update(conn, %{"id" => product_id, "quantity" => quantity}) do
    cart = get_session(conn, :cart) || %{items: %{}, total_items: 0}
    updated_cart = Cart.update_item(cart, product_id, quantity)

    conn
    |> put_session(:cart, updated_cart)
    |> redirect(to: ~p"/cart")
  end

  def remove(conn, %{"id" => product_id}) do
    cart = get_session(conn, :cart) || %{items: %{}, total_items: 0}
    updated_cart = Cart.remove_item(cart, product_id)

    conn
    |> put_session(:cart, updated_cart)
    |> redirect(to: ~p"/cart")
  end

  def clear(conn, _params) do
    updated_cart = Cart.clear_cart(nil)

    conn
    |> put_session(:cart, updated_cart)
    |> redirect(to: ~p"/cart")
  end
end
