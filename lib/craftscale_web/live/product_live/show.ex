defmodule CraftScaleWeb.ProductLive.Show do
  @moduledoc false
  use CraftScaleWeb, :live_view

  alias CraftScale.Inventory

  @impl true
  def render(assigns) do
    ~H"""
    <.header>
      <.breadcrumb>
        <:crumb label="All Products" path={~p"/manage/products"} current?={false} />
        <:crumb label={@product.name} path={~p"/manage/products/#{@product.id}"} current?={true} />
      </.breadcrumb>

      <:actions>
        <.link patch={~p"/manage/products/#{@product.id}/edit"} phx-click={JS.push_focus()}>
          <.button>Edit product</.button>
        </.link>
      </:actions>
    </.header>

    <div class="mt-4">
      <.tabs id="product-tabs">
        <:tab
          label="Details"
          path={~p"/manage/products/#{@product.id}?page=details"}
          selected?={@page == "details"}
        >
          <.list>
            <:item title="Status">
              <.badge
                text={Atom.to_string(@product.status)}
                colors={[
                  {@product.status,
                   "#{product_status_color(@product.status)} #{product_status_bg(@product.status)}"}
                ]}
              />
            </:item>
            <:item title="Name">{@product.name}</:item>

            <:item title="SKU">
              <.kbd>
                {@product.sku}
              </.kbd>
            </:item>

            <:item title="Price">
              {format_money(@settings.currency, @product.price)}
            </:item>

            <:item title="Allergens">
              <div class="flex-inline items-center space-x-1">
                <.badge :for={allergen <- Enum.map(@product.allergens, & &1.name)} text={allergen} />
                <span :if={Enum.empty?(@product.allergens)}>None</span>
              </div>
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
          </.list>
        </:tab>

        <:tab
          label="Recipe"
          path={~p"/manage/products/#{@product.id}?page=recipe"}
          selected?={@page == "recipe"}
        >
          <.live_component
            module={CraftScaleWeb.ProductLive.FormComponentRecipe}
            id="material-form"
            product={@product}
            recipe={@product.recipe || nil}
            current_user={@current_user}
            settings={@settings}
            materials={@materials_available}
            patch={~p"/manage/products/#{@product.id}?page=recipe"}
            on_cancel={hide_modal("product-material-modal")}
          />
        </:tab>
      </.tabs>
    </div>

    <.modal
      :if={@live_action == :edit}
      id="product-modal"
      show
      on_cancel={JS.patch(~p"/manage/products/#{@product.id}")}
    >
      <.live_component
        module={CraftScaleWeb.ProductLive.FormComponent}
        id={@product.id}
        title={@page_title}
        action={@live_action}
        current_user={@current_user}
        product={@product}
        settings={@settings}
        patch={~p"/manage/products/#{@product.id}?page=details"}
      />
    </.modal>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       page: "details",
       materials_available: list_available_materials()
     )}
  end

  @impl true
  def handle_params(%{"id" => id} = params, _, socket) do
    product =
      CraftScale.Catalog.get_product_by_id!(id,
        load: [
          :markup_percentage,
          :gross_profit,
          :materials_cost,
          :allergens,
          recipe: [components: [:material]]
        ]
      )

    page = Map.get(params, "page", "details")

    socket =
      socket
      |> assign(:page_title, page_title(socket.assigns.live_action))
      |> assign(:product, product)
      |> assign(:status_form, to_form(%{"status" => product.status}))
      |> assign(:page, page)

    {:noreply, socket}
  end

  @impl true
  def handle_info({CraftScaleWeb.ProductLive.FormComponentRecipe, {:saved, _}}, socket) do
    product =
      CraftScale.Catalog.get_product_by_sku!(socket.assigns.product.sku,
        load: [
          :markup_percentage,
          :materials_cost,
          :gross_profit,
          recipe: [components: [:material]]
        ]
      )

    {:noreply,
     socket
     |> put_flash(:info, "Recipe updated successfully")
     |> assign(:product, product)
     |> push_event("close-modal", %{id: "product-material-modal"})}
  end

  def handle_info({CraftScaleWeb.ProductLive.FormComponent, {:saved, _}}, socket) do
    product =
      CraftScale.Catalog.get_product_by_sku!(socket.assigns.product.sku,
        load: [
          :markup_percentage,
          :materials_cost,
          :gross_profit,
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

  defp page_title(:show), do: "Show Product"
  defp page_title(:edit), do: "Edit Product"

  defp list_available_materials do
    Inventory.list_materials!()
  end
end
