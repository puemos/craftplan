defmodule CraftplanWeb.Public.CatalogLive.Index do
  @moduledoc false
  use CraftplanWeb, :live_view

  alias Craftplan.Catalog

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
        <div class="aspect-w-1 aspect-h-1 w-full rounded bg-gray-200 group-hover:opacity-75 lg:aspect-none lg:h-80">
          <img
            :if={product.featured_photo}
            src={
              Craftplan.Catalog.Product.Photo.url({product.featured_photo, product}, :thumb,
                signed: true
              )
            }
            alt={product.name}
            class="h-full w-full overflow-hidden border border-stone-300 object-cover object-center lg:h-full lg:w-full"
          />
          <div
            :if={!product.featured_photo}
            class="h-full w-full border border-stone-300 bg-stone-100"
          >
          </div>
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
            <%= if cart_item = get_cart_item_for_product(@cart, product) do %>
              <div class="absolute top-0 right-0 z-10 rounded-bl-md bg-indigo-600 px-2 py-1 text-xs font-medium text-white">
                <.link navigate={~p"/cart"} class="text-white hover:text-white">
                  {cart_item.quantity} in cart
                </.link>
              </div>
            <% end %>
          </div>
          <p class="text-sm font-medium text-gray-900">
            {format_money(@settings.currency, product.price)}
          </p>
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

    {:ok, assign(socket, :products, products)}
  end

  defp get_cart_item_for_product(nil, _product), do: nil

  defp get_cart_item_for_product(cart, product) do
    Enum.find(cart.items, fn item -> item.product_id == product.id end)
  end
end
