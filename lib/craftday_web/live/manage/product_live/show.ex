defmodule CraftdayWeb.ProductLive.Show do
  @moduledoc false
  use CraftdayWeb, :live_view

  alias Craftday.Inventory

  @impl true
  def render(assigns) do
    ~H"""
    <.header>
      <.breadcrumb>
        <:crumb label="All Products" path={~p"/manage/products"} current?={false} />
        <:crumb label={@product.name} path={~p"/manage/products/#{@product.sku}"} current?={true} />
      </.breadcrumb>

      <:actions>
        <.link patch={~p"/manage/products/#{@product.sku}/edit"} phx-click={JS.push_focus()}>
          <.button>Edit product</.button>
        </.link>
      </:actions>
    </.header>

    <div class="mt-4">
      <.tabs id="product-tabs">
        <:tab
          label="Details"
          path={~p"/manage/products/#{@product.sku}/details"}
          selected?={@live_action == :details || @live_action == :show}
        >
          <.list>
            <:item title="Status">
              <.badge
                text={@product.status}
                colors={[
                  {@product.status,
                   "#{product_status_color(@product.status)} #{product_status_bg(@product.status)}"}
                ]}
              />
            </:item>
            <:item title="Availability">
              <.badge text={@product.selling_availability} />
            </:item>
            <:item title="Name">{@product.name}</:item>

            <:item title="SKU">
              <.kbd>
                {@product.sku}
              </.kbd>
            </:item>

            <:item title="Allergens">
              <div class="flex-inline items-center space-x-1">
                <.badge :for={allergen <- Enum.map(@product.allergens, & &1.name)} text={allergen} />
                <span :if={Enum.empty?(@product.allergens)}>None</span>
              </div>
            </:item>

            <:item title="Price">
              {format_money(@settings.currency, @product.price)}
            </:item>

            <:item title="Materials cost">
              {format_money(@settings.currency, @product.materials_cost)}
            </:item>

            <:item title="Gross profit">
              {format_money(@settings.currency, @product.gross_profit)}
            </:item>

            <:item title="Markup percentage">
              {format_percentage(@product.markup_percentage)}%
            </:item>

            <:item
              :if={@product.max_daily_quantity && @product.max_daily_quantity > 0}
              title="Max units per day"
            >
              {@product.max_daily_quantity}
            </:item>
          </.list>
        </:tab>

        <:tab
          label="Recipe"
          path={~p"/manage/products/#{@product.sku}/recipe"}
          selected?={@live_action == :recipe}
        >
          <.live_component
            module={CraftdayWeb.ProductLive.FormComponentRecipe}
            id="material-form"
            product={@product}
            recipe={@product.recipe || nil}
            current_user={@current_user}
            settings={@settings}
            materials={@materials_available}
            patch={~p"/manage/products/#{@product.sku}/recipe"}
            on_cancel={hide_modal("product-material-modal")}
          />
        </:tab>

        <:tab
          label="Nutrition"
          path={~p"/manage/products/#{@product.sku}/nutrition"}
          selected?={@live_action == :nutrition}
        >
          <div>
            <h3 class="my-4 text-lg font-medium">Nutritional Facts</h3>
            <p class="mb-4 text-sm text-stone-500">
              The nutritional information is automatically calculated from your recipe components.
            </p>
          </div>
          <.table id="nutritional-facts" rows={@product.nutritional_facts}>
            <:col :let={fact} label="Nutrient">{fact.name}</:col>
            <:col :let={fact} label="Amount">{format_amount(fact.unit, fact.amount)}</:col>
          </.table>
        </:tab>
        <:tab
          label="Photos"
          path={~p"/manage/products/#{@product.sku}/photos"}
          selected?={@live_action == :photos}
        >
          <.live_component
            module={CraftdayWeb.ProductLive.FormComponentPhotos}
            id={@product.id}
            title={@page_title}
            action={@live_action}
            current_user={@current_user}
            product={@product}
            settings={@settings}
            patch={~p"/manage/products/#{@product.sku}"}
          />
        </:tab>
      </.tabs>
    </div>

    <.modal
      :if={@live_action == :edit}
      id="product-modal"
      title={@page_title}
      description="Update product information and details."
      show
      on_cancel={JS.patch(~p"/manage/products/#{@product.sku}")}
    >
      <.live_component
        module={CraftdayWeb.ProductLive.FormComponent}
        id={@product.id}
        title={@page_title}
        action={@live_action}
        current_user={@current_user}
        product={@product}
        settings={@settings}
        patch={~p"/manage/products/#{@product.sku}/details"}
      />
    </.modal>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       materials_available: list_available_materials()
     )}
  end

  @impl true
  def handle_params(%{"sku" => sku}, _, socket) do
    product =
      Craftday.Catalog.get_product_by_sku!(sku,
        load: [
          :markup_percentage,
          :gross_profit,
          :materials_cost,
          :allergens,
          :nutritional_facts,
          recipe: [components: [:material]]
        ]
      )

    socket =
      socket
      |> assign(:page_title, page_title(socket.assigns.live_action))
      |> assign(:product, product)
      |> assign(:status_form, to_form(%{"status" => product.status}))

    {:noreply, socket}
  end

  @impl true
  def handle_info({CraftdayWeb.ProductLive.FormComponentPhotos, {:saved, _}}, socket) do
    product =
      Craftday.Catalog.get_product_by_sku!(socket.assigns.product.sku,
        load: [
          :markup_percentage,
          :materials_cost,
          :gross_profit,
          :nutritional_facts,
          recipe: [components: [:material]]
        ]
      )

    {:noreply,
     socket
     |> put_flash(:info, "Photos updated successfully")
     |> assign(:product, product)}
  end

  @impl true
  def handle_info({CraftdayWeb.ProductLive.FormComponentRecipe, {:saved, _}}, socket) do
    product =
      Craftday.Catalog.get_product_by_sku!(socket.assigns.product.sku,
        load: [
          :markup_percentage,
          :materials_cost,
          :gross_profit,
          :nutritional_facts,
          :allergens,
          recipe: [components: [:material]]
        ]
      )

    {:noreply,
     socket
     |> put_flash(:info, "Recipe updated successfully")
     |> assign(:product, product)
     |> push_event("close-modal", %{id: "product-material-modal"})}
  end

  def handle_info({CraftdayWeb.ProductLive.FormComponent, {:saved, _}}, socket) do
    product =
      Craftday.Catalog.get_product_by_sku!(socket.assigns.product.sku,
        load: [
          :markup_percentage,
          :materials_cost,
          :gross_profit,
          :nutritional_facts,
          :allergens,
          recipe: [components: [:material]]
        ]
      )

    {:noreply,
     socket
     |> put_flash(:info, "Product updated successfully")
     |> assign(:product, product)}
  end

  @impl true
  def handle_event("product-status-change", %{"_target" => ["status"], "status" => status}, socket) do
    case Ash.update(socket.assigns.product, %{status: status}) do
      {:ok, product} ->
        {:noreply,
         socket
         |> put_flash(:info, "Product updated successfully")
         |> assign(:product, product)}

      {:error, _} ->
        {:noreply, socket}
    end
  end

  defp page_title(:show), do: "Product"
  defp page_title(:nutrition), do: "Product Nutritional Information"
  defp page_title(:edit), do: "Modify Product"
  defp page_title(:recipe), do: "Product Recipe"
  defp page_title(:details), do: "Product"
  defp page_title(_), do: "Product"

  defp list_available_materials do
    Inventory.list_materials!()
  end
end
