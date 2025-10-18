defmodule CraftplanWeb.Public.CatalogLive.Show do
  @moduledoc false
  use CraftplanWeb, :live_view

  alias Craftplan.Cart
  alias Craftplan.Catalog
  alias Craftplan.Catalog.Product.Photo

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
      <!-- Left column: Gallery + Product Details -->
      <div class="space-y-6 lg:col-span-1">
        <!-- Photo gallery -->
        <div :if={not Enum.empty?(@product.photos)} class="gallery mb-6">
          <!-- Main image (first photo) -->

          <!-- Thumbnail strip -->
          <div class="thumbnails grid grid-cols-4 gap-2">
            <img
              src={Photo.url({@product.featured_photo, @product}, :thumb, signed: true)}
              phx-click={show_modal("photos-modal")}
              alt={@product.name}
              class="w-full cursor-pointer rounded-lg object-cover"
            />
          </div>
        </div>
        
    <!-- Product info -->
        <div>
          <h1 class="text-3xl font-bold tracking-tight text-gray-900 sm:text-4xl">
            {@product.name}
          </h1>
        </div>

        <div class="flex items-center gap-3">
          <p class="text-lg text-gray-900 sm:text-xl">
            {format_money(@settings.currency, @product.price)}
          </p>
          <.badge :if={@product.selling_availability == :preorder} text="Preorder" />
          <.badge :if={@product.selling_availability == :off} text="Unavailable" />
        </div>

        <div :if={not Enum.empty?(@product.allergens)} class="space-y-2">
          <h3 class="text-sm font-medium text-gray-900">Allergens</h3>
          <div class="flex flex-wrap items-center gap-2">
            <.badge :for={allergen <- @product.allergens} text={allergen.name} />
          </div>
        </div>

        <section aria-labelledby="options-heading" class="space-y-4">
          <h2 id="options-heading" class="sr-only">Product options</h2>

          <form phx-submit="add_to_cart" class="space-y-4">
            <input type="hidden" name="product_id" value={@product.id} />

            <div>
              <.input
                name="quantity"
                type="number"
                value={
                  existing_item =
                    Enum.find(@cart.items || [], fn item -> item.product_id == @product.id end)

                  if existing_item, do: existing_item.quantity, else: 1
                }
                min="1"
                label="Quantity"
                required
              />
            </div>

            <.button
              variant={:primary}
              class="mt-4 w-full"
              disabled={@product.selling_availability == :off}
            >
              {existing_item =
                Enum.find(@cart.items || [], fn item -> item.product_id == @product.id end)

              if existing_item, do: "Update cart", else: "Add to cart"}
            </.button>
          </form>
          <p :if={@product.selling_availability == :off} class="text-sm text-stone-500">
            This product is currently unavailable.
          </p>
        </section>
      </div>
      
    <!-- Right column: Nutritional Information -->
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

    <.modal
      id="photos-modal"
      title={@product.name}
      description="Product photo gallery"
      max_width="max-w-none"
    >
      <div class="flex flex-row gap-4">
        <!-- Thumbnails on the left -->
        <div class="grid w-1/6 grid-cols-2 gap-2">
          <img
            :for={{photo, index} <- Enum.with_index(@product.photos)}
            src={Photo.url({photo, @product}, :thumb, signed: true)}
            alt={"#{@product.name} - photo #{index + 1}"}
            class={"#{if @selected_photo_index == index, do: "ring-primary ring-2", else: "hover:ring-primary hover:ring-2"} cursor-pointer rounded object-cover transition-all"}
            phx-click={JS.push("select_photo", value: %{index: index})}
          />
        </div>
        
    <!-- Main image on the right -->
        <div class="flex w-5/6 justify-center">
          <img
            :if={@selected_photo_index}
            src={
              Photo.url({Enum.at(@product.photos, @selected_photo_index), @product}, :original,
                signed: true
              )
            }
            alt={"#{@product.name} - photo #{@selected_photo_index + 1}"}
            class="max-h-[70vh] rounded object-contain"
          />
          <img
            :if={!@selected_photo_index && !Enum.empty?(@product.photos)}
            src={Photo.url({List.first(@product.photos), @product}, :original, signed: true)}
            alt={@product.name}
            class="max-h-[70vh] rounded object-contain"
          />
        </div>
      </div>
    </.modal>
    """
  end

  @impl true
  def mount(%{"sku" => sku}, _session, socket) do
    product =
      Catalog.get_product_by_sku!(sku,
        load: [:allergens, :nutritional_facts, :photos, :selling_availability]
      )

    {:ok,
     socket
     |> assign(:product, product)
     |> assign(:selected_photo_index, 0)}
  end

  @impl true
  def handle_event("select_photo", %{"index" => index}, socket) do
    {:noreply, assign(socket, :selected_photo_index, index)}
  end

  @impl true
  def handle_event("add_to_cart", %{"product_id" => product_id, "quantity" => quantity}, socket) do
    quantity = String.to_integer(quantity)

    cart =
      Ash.load!(
        socket.assigns.cart,
        [items: [:product]],
        context: %{cart_id: socket.assigns.cart.id}
      )

    cart_items = cart.items || []

    product = socket.assigns.product

    # Guard: availability
    if socket.assigns.product.selling_availability == :off do
      {:noreply, put_flash(socket, :error, "This product is unavailable.")}
    else
      # Check if product already in cart
      existing_item = Enum.find(cart_items, fn item -> item.product_id == product_id end)

      if existing_item do
        # Update existing item
        new_quantity = quantity

        {:ok, _} =
          Cart.update_cart_item(
            existing_item,
            %{quantity: new_quantity},
            context: %{cart_id: existing_item.cart_id}
          )
      else
        # Create new item
        {:ok, _} =
          Cart.create_cart_item(%{
            cart_id: cart.id,
            product_id: product_id,
            quantity: quantity,
            price: product.price
          })
      end

      cart = Ash.reload!(cart, load: [items: [:product]], context: %{cart_id: cart.id})

      {:noreply,
       socket
       |> assign(:cart, cart)
       |> put_flash(:info, "Product added to cart.")}
    end
  end
end
