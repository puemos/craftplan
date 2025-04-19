defmodule CraftdayWeb.Public.CatalogLive.Index do
  @moduledoc false
  use CraftdayWeb, :live_view

  alias Craftday.Catalog

  @impl true
  def render(assigns) do
    ~H"""
    <.header>
      <.breadcrumb>
        <:crumb label="All Products" path={~p"/catalog"} current?={true} />
      </.breadcrumb>
    </.header>

    <div class="mt-6 grid grid-cols-1 gap-x-6 gap-y-10 sm:grid-cols-2 lg:grid-cols-4 xl:gap-x-8">
      <div :for={product <- @products} class="group relative">
        <div class="aspect-w-1 aspect-h-1 w-full overflow-hidden rounded-md bg-gray-200 group-hover:opacity-75 lg:aspect-none lg:h-80">
          <div class="h-full w-full bg-stone-100"></div>
        </div>
        <div class="mt-4 flex justify-between">
          <div>
            <h3 class="text-sm text-gray-700">
              <.link
                navigate={~p"/catalog/#{product.sku}"}
                class="font-medium text-gray-800 hover:text-gray-900"
              >
                <span aria-hidden="true" class="absolute inset-0"></span>
                {product.name}
              </.link>
            </h3>
          </div>
          <p class="text-sm font-medium text-gray-900">
            {format_money(@settings.currency, product.price)}
          </p>
        </div>
      </div>
    </div>

    <div :if={@cart_items != []} class="fixed right-0 bottom-0 left-0">
      <div class="mx-auto max-w-7xl px-2 py-2 sm:px-6 lg:px-8">
        <div class="rounded-lg bg-stone-800 p-2 shadow-lg">
          <div class="flex flex-wrap items-center justify-between">
            <div class="flex w-0 flex-1 items-center">
              <span class="flex rounded-lg bg-stone-900 p-2">
                <svg
                  class="h-6 w-6 text-white"
                  fill="none"
                  viewBox="0 0 24 24"
                  stroke-width="1.5"
                  stroke="currentColor"
                  aria-hidden="true"
                >
                  <path
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    d="M2.25 3h1.386c.51 0 .955.343 1.087.835l.383 1.437M7.5 14.25a3 3 0 00-3 3h15.75m-12.75-3h11.218c1.121-2.3 2.1-4.684 2.924-7.138a60.114 60.114 0 00-16.536-1.84M7.5 14.25L5.106 5.272M6 20.25a.75.75 0 11-1.5 0 .75.75 0 011.5 0zm12.75 0a.75.75 0 11-1.5 0 .75.75 0 011.5 0z"
                  />
                </svg>
              </span>
              <p class="ml-3 truncate font-medium text-white">
                <span class="md:hidden">
                  {length(@cart_items)} items ({format_money(
                    @settings.currency,
                    cart_total(@cart_items)
                  )})
                </span>
                <span class="hidden md:inline">
                  {length(@cart_items)} items in your cart
                  ({format_money(@settings.currency, cart_total(@cart_items))})
                </span>
              </p>
            </div>
            <div class="order-3 mt-2 w-full flex-shrink-0 sm:order-2 sm:mt-0 sm:w-auto">
              <.link
                navigate={~p"/cart"}
                class="flex items-center justify-center rounded-md bg-white px-3 py-2 text-sm font-semibold text-stone-600 shadow-sm hover:bg-stone-50"
              >
                View cart
              </.link>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    # if connected?(socket), do: Orders.subscribe()

    products =
      Catalog.list_products!(
        %{status: [:active]},
        actor: socket.assigns[:current_user]
      )

    {:ok, socket |> assign(:products, products) |> assign(:cart_items, [])}
  end

  defp cart_total(items) do
    Enum.reduce(items, Decimal.new(0), fn item, acc ->
      Decimal.add(acc, Decimal.mult(item.product.price, item.quantity))
    end)
  end
end
