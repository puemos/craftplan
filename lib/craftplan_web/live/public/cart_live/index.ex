defmodule CraftplanWeb.Public.CartLive.Index do
  @moduledoc false
  use CraftplanWeb, :live_view

  alias Craftplan.Cart
  alias Craftplan.Catalog.Product.Photo

  @impl true
  def render(assigns) do
    ~H"""
    <.header>
      <.breadcrumb>
        <:crumb label="Shopping Cart" path={~p"/cart"} current?={true} />
      </.breadcrumb>
    </.header>

    <div class="">
      <h1 class="sr-only">Shopping Cart</h1>

      <div class="mt-12 lg:grid lg:grid-cols-12 lg:items-start lg:gap-x-12 xl:gap-x-16">
        <section aria-labelledby="cart-heading" class="lg:col-span-7">
          <h2 id="cart-heading" class="sr-only">Items in your shopping cart</h2>

          <ul
            :if={@cart_items != []}
            role="list"
            class="divide-y divide-stone-200 border-t border-b border-stone-200"
          >
            <li :for={item <- @cart_items} class="flex py-6 sm:py-10">
              <div class="h-24 w-24 flex-shrink-0 overflow-hidden rounded-md border border-stone-200">
                <img
                  :if={item.product.featured_photo}
                  src={Photo.url({item.product.featured_photo, item.product}, :thumb, signed: true)}
                  alt={item.product.name}
                  class="h-full w-full object-cover object-center"
                />
              </div>
              <div class="ml-4 flex flex-1 flex-col justify-between sm:ml-6">
                <div class="relative pr-9 sm:grid sm:grid-cols-2 sm:gap-x-6 sm:pr-0">
                  <div>
                    <div class="flex justify-between">
                      <h3 class="text-sm">
                        <.link
                          navigate={~p"/catalog/#{item.product.sku}"}
                          class="font-medium text-stone-700 hover:text-stone-800"
                        >
                          {item.product.name}
                        </.link>
                      </h3>
                    </div>
                    <p class="mt-1 flex items-center text-sm font-medium text-stone-900">
                      <span class="inline-block">
                        {format_money(@settings.currency, item.price)}
                      </span>
                      <span class="mx-1 text-stone-500">×</span>
                      <span class="inline-block">{Decimal.new(item.quantity)}</span>
                    </p>
                  </div>

                  <div class="mt-4 flex items-baseline space-x-4 sm:mt-0 sm:pr-9">
                    <form
                      id={"update-item-#{item.id}"}
                      phx-submit="update_item"
                      class="flex items-center space-x-2"
                    >
                      <input type="hidden" name="item_id" value={item.id} />
                      <.input
                        name="quantity"
                        type="number"
                        min="1"
                        value={item.quantity}
                        class="max-w-full rounded-md border border-stone-300 py-1.5 text-left text-base font-medium leading-5 text-stone-700 focus:border-stone-500 focus:outline-none focus:ring-1 focus:ring-stone-500 sm:text-sm"
                      />
                      <.button class="mt-2">Update</.button>
                    </form>
                    <form phx-submit="delete_item" class="flex items-center space-x-2">
                      <input type="hidden" name="item_id" value={item.id} />

                      <.button class="mt-2">Remove</.button>
                    </form>
                  </div>
                </div>
                <p class="mt-2 flex space-x-2 text-sm text-stone-700">
                  <span>
                    Item total: {format_money(
                      @settings.currency,
                      Decimal.mult(item.price, Decimal.new(item.quantity))
                    )}
                  </span>
                </p>
              </div>
            </li>
          </ul>

          <div :if={@cart_items == []} class="py-12 text-center">
            <p class="text-sm text-stone-500">Your cart is empty</p>
            <.link navigate={~p"/catalog"} class="text-sm text-blue-500 hover:text-blue-600">
              Continue Shopping
            </.link>
          </div>
        </section>

        <section
          :if={@cart_items != []}
          aria-labelledby="summary-heading"
          class="mt-16 rounded border border-stone-200 bg-white px-4 py-6 sm:p-6 lg:col-span-5 lg:mt-0 lg:p-8"
        >
          <h2 id="summary-heading" class="mb-4 text-lg font-medium text-stone-900">Order summary</h2>

          <.list>
            <:item title="Subtotal">
              {format_money(@settings.currency, cart_total(@cart_items))}
            </:item>
            <:item title="Order total">
              {format_money(@settings.currency, cart_total(@cart_items))}
            </:item>
          </.list>

          <div class="mt-8 flex space-y-3">
            <.link navigate={~p"/checkout"} class="h-10 w-full">
              <.button variant={:primary} expanding={true}>
                Checkout
              </.button>
            </.link>
          </div>
        </section>
      </div>
    </div>
    """
  end

  @impl true
  def mount(_params, session, socket) do
    cart_assign = socket.assigns[:cart]

    cart =
      cond do
        cart_assign ->
          Ash.load!(cart_assign, [items: [:product]], context: %{cart_id: cart_assign.id})

        is_binary(session["cart_id"]) or is_binary(session[:cart_id]) ->
          cart_id = session["cart_id"] || session[:cart_id]
          cart = Cart.get_cart_by_id!(cart_id, context: %{cart_id: cart_id})
          Ash.load!(cart, [items: [:product]], context: %{cart_id: cart_id})

        true ->
          nil
      end

    cart_id = if cart, do: cart.id

    cart_items =
      if cart_id do
        [context: %{cart_id: cart_id}]
        |> Cart.list_cart_items!()
        |> Ash.load!([:product], context: %{cart_id: cart_id})
      else
        []
      end

    {:ok, assign(socket, cart_items: cart_items)}
  end

  @impl true
  def handle_event("update_item", %{"item_id" => item_id, "quantity" => quantity}, socket) do
    quantity = String.to_integer(quantity)

    if quantity > 0 do
      cart_item = Cart.get_cart_item_by_id!(item_id, context: %{cart_id: socket.assigns.cart.id})

      {:ok, _updated_item} =
        Cart.update_cart_item(cart_item, %{quantity: quantity}, context: %{cart_id: socket.assigns.cart.id})

      # Refresh the cart items
      cart = Cart.get_cart_by_id!(cart_item.cart_id, context: %{cart_id: cart_item.cart_id})
      cart = Ash.load!(cart, [items: [:product]], context: %{cart_id: cart.id})

      {:noreply, assign(socket, cart_items: cart.items || [])}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("delete_item", %{"item_id" => item_id}, socket) do
    cart_item = Cart.get_cart_item_by_id!(item_id, context: %{cart_id: socket.assigns.cart.id})
    :ok = Cart.delete_cart_item(cart_item, context: %{cart_id: socket.assigns.cart.id})

    # Refresh the cart items
    cart = Cart.get_cart_by_id!(cart_item.cart_id, context: %{cart_id: cart_item.cart_id})
    cart = Ash.load!(cart, [items: [:product]], context: %{cart_id: cart.id})

    {:noreply, assign(socket, cart_items: cart.items || [])}
  end

  defp cart_total(items) do
    Enum.reduce(items, Decimal.new(0), fn item, acc ->
      Decimal.add(acc, Decimal.mult(item.price, Decimal.new(item.quantity)))
    end)
  end
end
