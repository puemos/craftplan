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
      cart =
        if session["cart_id"] do
          Cart.get_cart_by_id!(session["cart_id"], load: [:items])
        end

      socket
      |> assign(:cart, cart)
      |> then(&{:cont, &1})
    end
  end
end
