defmodule CraftplanWeb.ProductLive.Index do
  @moduledoc false
  use CraftplanWeb, :live_view

  alias Craftplan.Catalog
  alias Craftplan.Catalog.Product.Photo

  @impl true
  def render(assigns) do
    assigns =
      assign_new(assigns, :breadcrumbs, fn -> [] end)

    ~H"""
    <.header>
      Products
      <:actions>
        <.link patch={~p"/manage/products/new"}>
          <.button variant={:primary}>New Product</.button>
        </.link>
      </:actions>
    </.header>

    <.table
      id="products"
      rows={@streams.products}
      row_click={fn {_, product} -> JS.navigate(~p"/manage/products/#{product.sku}") end}
      row_id={fn {dom_id, _} -> dom_id end}
    >
      <:empty>
        <div class="block py-4 pr-6">
          <span class={["relative"]}>
            No products found
          </span>
        </div>
      </:empty>
      <:col :let={{_, product}} label="Name">
        <div class="flex items-center space-x-2">
          <img
            :if={product.featured_photo != nil}
            src={Photo.url({product.featured_photo, product}, :thumb, signed: true)}
            alt={product.name}
            class="h-5 w-5"
          />
          <span>
            {product.name}
          </span>
        </div>
      </:col>
      <:col :let={{_, product}} label="SKU">
        <.kbd>
          {product.sku}
        </.kbd>
      </:col>
      <:col :let={{_, product}} label="Status">
        <.badge
          text={product.status}
          colors={[
            {product.status,
             "#{product_status_color(product.status)} #{product_status_bg(product.status)}"}
          ]}
        />
      </:col>
      <:col :let={{_, product}} label="Price">
        {format_money(@settings.currency, product.price)}
      </:col>

      <:col :let={{_, product}} label="Materials cost">
        {format_money(@settings.currency, product.materials_cost)}
      </:col>

      <:col :let={{_, product}} label="Gross profit">
        {format_money(@settings.currency, product.gross_profit)}
      </:col>

      <:action :let={{_, product}}>
        <.link
          phx-click={JS.push("delete", value: %{id: product.id}) |> hide("#product-#{product.id}")}
          data-confirm="Are you sure?"
        >
          <.button size={:sm} variant={:danger}>
            Delete
          </.button>
        </.link>
      </:action>
    </.table>

    <.modal
      :if={@live_action in [:new, :edit]}
      id="product-modal"
      show
      title={@page_title}
      on_cancel={JS.patch(~p"/manage/products")}
    >
      <.live_component
        module={CraftplanWeb.ProductLive.FormComponent}
        id={(@product && @product.id) || :new}
        title={@page_title}
        action={@live_action}
        product={@product}
        current_user={@current_user}
        settings={@settings}
        patch={~p"/manage/products"}
      />
    </.modal>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    products =
      Catalog.list_products!(
        actor: socket.assigns[:current_user],
        page: [limit: 100],
        load: [
          :materials_cost,
          :bom_unit_cost,
          :markup_percentage,
          :gross_profit
        ]
      )

    results = case products do
      %Ash.Page.Keyset{results: res} -> res
      %Ash.Page.Offset{results: res} -> res
      other -> other
    end

    socket =
      socket
      |> assign(:breadcrumbs, [
        %{label: "Products", path: ~p"/manage/products", current?: true}
      ])
      |> stream(:products, results)

    {:ok, socket}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :new, _params) do
    socket
    |> assign(:page_title, "New Product")
    |> assign(:product, nil)
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "Catalog")
    |> assign(:product, nil)
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    case id
         |> Catalog.get_product_by_id!(actor: socket.assigns.current_user)
         |> Ash.destroy(actor: socket.assigns.current_user) do
      :ok ->
        {:noreply,
         socket
         |> put_flash(:info, "Product deleted successfully")
         |> stream_delete(:products, %{id: id})}

      {:error, _error} ->
        {:noreply, put_flash(socket, :error, "Failed to delete product.")}
    end
  end

  @impl true
  def handle_info({CraftplanWeb.ProductLive.FormComponent, {:saved, product}}, socket) do
    product =
      Ash.load!(product, [:materials_cost, :bom_unit_cost, :markup_percentage, :gross_profit],
        actor: socket.assigns.current_user
      )

    {:noreply, stream_insert(socket, :products, product)}
  end
end
