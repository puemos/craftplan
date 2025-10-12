defmodule CraftdayWeb.LiveCart do
  @moduledoc """
  Helpers for authenticating users in LiveViews.
  """
  use CraftdayWeb, :verified_routes

  import Phoenix.Component

  alias Craftday.Cart

  def on_mount(:default, _params, session, socket) do
    if socket.assigns[:cart] do
      {:cont, socket}
    else
      cart_id = session["cart_id"] || session[:cart_id]

      cart =
        if cart_id do
          Cart.get_cart_by_id!(cart_id, load: [:items], context: %{cart_id: cart_id})
        end

      socket
      |> assign(:cart, cart)
      |> then(&{:cont, &1})
    end
  end
end
