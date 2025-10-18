defmodule CraftplanWeb.CartLive do
  @moduledoc false
  use CraftplanWeb, :live_view_blank

  alias Craftplan.Cart

  @impl true
  def mount(_params, session, socket) do
    if connected?(socket) do
      CraftplanWeb.Endpoint.subscribe("cart_items")
    end

    cart =
      Cart.get_cart_by_id!(
        session["cart_id"],
        context: %{cart_id: session["cart_id"]}
      )

    cart = Ash.load!(cart, [:total_items], context: %{cart_id: cart.id})
    dbg(cart)
    {:ok, assign(socket, :cart, cart)}
  end

  @impl true
  def handle_info(%Phoenix.Socket.Broadcast{topic: "cart_items"}, socket) do
    cart =
      Cart.get_cart_by_id!(
        socket.assigns.cart.id,
        load: [:total_items],
        context: %{cart_id: socket.assigns.cart.id}
      )

    {:noreply, assign(socket, :cart, cart)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.link
      href={~p"/cart"}
      class="flex items-center rounded-md border border-transparent px-2 py-1 text-sm tracking-wide text-stone-600 transition-colors duration-200 hover:bg-stone-200/50 hover:text-stone-900"
    >
      <svg class="mr-1 h-4 w-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
        <path
          stroke-linecap="round"
          stroke-linejoin="round"
          stroke-width="2"
          d="M3 3h2l.4 2M7 13h10l4-8H5.4M7 13L5.4 5M7 13l-2.293 2.293c-.63.63-.184 1.707.707 1.707H17m0 0a2 2 0 100 4 2 2 0 000-4zm-8 2a2 2 0 11-4 0 2 2 0 014 0z"
        />
      </svg>
      Cart {if @cart.total_items != nil and @cart.total_items > 0, do: "(#{@cart.total_items})"}
    </.link>
    """
  end
end
