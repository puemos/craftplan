defmodule CraftdayWeb.Public.CartLive.Index do
  @moduledoc false
  use CraftdayWeb, :live_view

  @impl true
  def render(assigns) do
    ~H"""
    <div class="mx-auto max-w-2xl px-4 pt-16 pb-24 sm:px-6 lg:max-w-7xl lg:px-8">
      <h1 class="text-3xl font-bold tracking-tight text-gray-900 sm:text-4xl">Shopping Cart</h1>

      <div class="mt-12 lg:grid lg:grid-cols-12 lg:items-start lg:gap-x-12 xl:gap-x-16">
        <section aria-labelledby="cart-heading" class="lg:col-span-7">
          <h2 id="cart-heading" class="sr-only">Items in your shopping cart</h2>

          <ul
            :if={@cart_items != []}
            role="list"
            class="divide-y divide-gray-200 border-t border-b border-gray-200"
          >
            <li :for={item <- @cart_items} class="flex py-6 sm:py-10">
              <div class="ml-4 flex flex-1 flex-col justify-between sm:ml-6">
                <div class="relative pr-9 sm:grid sm:grid-cols-2 sm:gap-x-6 sm:pr-0">
                  <div>
                    <div class="flex justify-between">
                      <h3 class="text-sm">
                        <.link
                          navigate={~p"/catalog/#{item.product.sku}"}
                          class="font-medium text-gray-700 hover:text-gray-800"
                        >
                          {item.product.name}
                        </.link>
                      </h3>
                    </div>
                    <p class="mt-1 text-sm font-medium text-gray-900">
                      {format_money(@settings.currency, item.product.price)}
                    </p>
                  </div>

                  <div class="mt-4 sm:mt-0 sm:pr-9">
                    <.form
                      :let={_f}
                      for={%{}}
                      as={:cart_item}
                      action={~p"/cart/update/#{item.product.id}"}
                      method="put"
                    >
                      <div class="flex items-center">
                        <.input
                          name="quantity"
                          type="number"
                          min="1"
                          value={item.quantity}
                          class="max-w-full rounded-md border border-gray-300 py-1.5 text-left text-base font-medium leading-5 text-gray-700 shadow-sm focus:border-stone-500 focus:outline-none focus:ring-1 focus:ring-stone-500 sm:text-sm"
                        />
                        <.button class="ml-2">Update</.button>
                      </div>
                    </.form>

                    <div class="absolute top-0 right-0">
                      <.form for={%{}} action={~p"/cart/remove/#{item.product.id}"} method="delete">
                        <button
                          type="submit"
                          class="-m-2 inline-flex p-2 text-gray-400 hover:text-gray-500"
                        >
                          <span class="sr-only">Remove</span>
                          <.icon name="hero-x-mark" class="h-5 w-5" />
                        </button>
                      </.form>
                    </div>
                  </div>
                </div>
              </div>
            </li>
          </ul>

          <div :if={@cart_items == []} class="py-12 text-center">
            <p class="text-sm text-gray-500">Your cart is empty</p>
            <.link navigate={~p"/catalog"} class="text-sm text-blue-500 hover:text-blue-600">
              Continue Shopping
            </.link>
          </div>
        </section>
        
    <!-- Order summary -->
        <section
          :if={@cart_items != []}
          aria-labelledby="summary-heading"
          class="mt-16 rounded-lg bg-gray-50 px-4 py-6 sm:p-6 lg:col-span-5 lg:mt-0 lg:p-8"
        >
          <h2 id="summary-heading" class="text-lg font-medium text-gray-900">Order summary</h2>

          <dl class="mt-6 space-y-4">
            <div class="flex items-center justify-between">
              <dt class="text-sm text-gray-600">Subtotal</dt>
              <dd class="text-sm font-medium text-gray-900">
                {format_money(@settings.currency, cart_total(@cart_items))}
              </dd>
            </div>
            <div class="flex items-center justify-between border-t border-gray-200 pt-4">
              <dt class="text-base font-medium text-gray-900">Order total</dt>
              <dd class="text-base font-medium text-gray-900">
                {format_money(@settings.currency, cart_total(@cart_items))}
              </dd>
            </div>
          </dl>

          <div class="mt-6">
            <.link
              navigate={~p"/checkout"}
              class="w-full rounded-md border border-transparent bg-stone-600 px-4 py-3 text-base font-medium text-white shadow-sm hover:bg-stone-700 focus:outline-none focus:ring-2 focus:ring-stone-500 focus:ring-offset-2 focus:ring-offset-gray-50"
            >
              Checkout
            </.link>
          </div>

          <div class="mt-2">
            <.form for={%{}} action={~p"/cart/clear"} method="post">
              <.button class="w-full border border-stone-300 bg-white text-stone-700 hover:bg-stone-100">
                Clear Cart
              </.button>
            </.form>
          </div>
        </section>
      </div>
    </div>
    """
  end

  @impl true
  def mount(_params, session, socket) do
    cart = session["cart"] || %{items: %{}, total_items: 0}
    cart_items = Map.values(cart.items || %{})

    {:ok, assign(socket, cart_items: cart_items)}
  end

  defp cart_total(items) do
    Enum.reduce(items, Decimal.new(0), fn item, acc ->
      Decimal.add(acc, Decimal.mult(item.product.price, Decimal.new(item.quantity)))
    end)
  end
end
