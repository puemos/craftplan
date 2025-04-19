defmodule CraftdayWeb.Public.CatalogLive.Show do
  @moduledoc false
  use CraftdayWeb, :live_view

  alias Craftday.Catalog

  @impl true
  def render(assigns) do
    ~H"""
    <.header>
      <.breadcrumb>
        <:crumb label="All Products" path={~p"/catalog"} current?={false} />
        <:crumb label={@product.name} path={~p"/catalog/#{@product.id}"} current?={true} />
      </.breadcrumb>
    </.header>

    <div class="py-6 lg:grid lg:grid-cols-2 lg:gap-x-8 lg:gap-y-12">
      <!-- Left Column: Product Details -->
      <div class="space-y-6 lg:col-span-1">
        <div>
          <h1 class="text-3xl font-bold tracking-tight text-gray-900 sm:text-4xl">
            {@product.name}
          </h1>
        </div>

        <div>
          <p class="text-lg text-gray-900 sm:text-xl">
            {format_money(@settings.currency, @product.price)}
          </p>
        </div>

        <div :if={not Enum.empty?(@product.allergens)} class="space-y-2">
          <h3 class="text-sm font-medium text-gray-900">Allergens</h3>
          <div class="flex flex-wrap items-center gap-2">
            <.badge :for={allergen <- @product.allergens} text={allergen.name} />
            <span :if={Enum.empty?(@product.allergens)} class="text-sm text-gray-500">None</span>
          </div>
        </div>

        <section aria-labelledby="options-heading" class="space-y-4">
          <h2 id="options-heading" class="sr-only">Product options</h2>

          <.form :let={_f} for={%{}} as={:cart_item} action={~p"/cart/add"} method="post">
            <.input type="hidden" name="product_id" value={@product.id} />

            <div>
              <.input name="quantity" type="number" value="1" min="1" label="Quantity" required />
            </div>

            <.button class="mt-4 w-full">Add to cart</.button>
          </.form>
        </section>
      </div>
      
    <!-- Right Column: Nutritional Information -->
      <div class="rounded-lg border border-stone-200 bg-white p-3 lg:col-span-1 lg:max-w-lg">
        <section aria-labelledby="information-heading">
          <h2 id="information-heading" class="sr-only">Product information</h2>

          <div class="space-y-6">
            <div :if={not Enum.empty?(@product.nutritional_facts)} class="space-y-2">
              <h3 class="text-sm font-medium text-gray-900">Nutritional Information</h3>
              <.table id="nutritional-facts" rows={@product.nutritional_facts}>
                <:col :let={fact} label="Nutrient">{fact.name}</:col>
                <:col :let={fact} label="Amount">{format_amount(fact.unit, fact.amount)}</:col>
              </.table>
            </div>
          </div>
        </section>
      </div>
    </div>
    """
  end

  @impl true
  def mount(%{"sku" => sku}, _session, socket) do
    product =
      Catalog.get_product_by_sku!(sku,
        load: [:allergens, :nutritional_facts]
      )

    {:ok, assign(socket, :product, product)}
  end
end
