defmodule MicrocraftWeb.ProductLive.Index do
  @moduledoc false
  use MicrocraftWeb, :live_view

  alias Microcraft.Catalog

  @impl true
  def render(assigns) do
    ~H"""
    <.header>
      Manage your products
      <:subtitle>
        <.breadcrumb>
          <:crumb label="Products" path={~p"/backoffice/products"} current?={true} />
        </.breadcrumb>
      </:subtitle>
      <:actions>
        <.link patch={~p"/backoffice/products/new"}>
          <.button>New Product</.button>
        </.link>
      </:actions>
    </.header>

    <.table
      id="products"
      rows={@streams.products}
      row_click={fn {_, product} -> JS.navigate(~p"/backoffice/products/#{product.id}") end}
      row_id={fn {dom_id, _} -> dom_id end}
    >
      <:col :let={{_, product}} label="Name">{product.name}</:col>

      <:col :let={{_, product}} label="Price">
        {Money.from_float!(:USD, Decimal.to_float(product.price))}
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
      <:action :let={{_, product}}>
        <.link
          phx-click={JS.push("delete", value: %{id: product.id}) |> hide("#product-#{product.id}")}
          data-confirm="Are you sure?"
        >
          Delete
        </.link>
      </:action>
    </.table>

    <.modal
      :if={@live_action in [:new, :edit]}
      id="product-modal"
      show
      on_cancel={JS.patch(~p"/backoffice/products")}
    >
      <.live_component
        module={MicrocraftWeb.ProductLive.FormComponent}
        id={(@product && @product.id) || :new}
        title={@page_title}
        action={@live_action}
        product={@product}
        current_user={@current_user}
        patch={~p"/backoffice/products"}
      />
    </.modal>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    products =
      Catalog.list_products!(
        actor: socket.assigns[:current_user],
        stream?: true,
        load: [:estimated_cost, :profit_margin]
      )

    {:ok, socket |> stream(:products, products)}
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
    case Catalog.get_product_by_id!(id) |> Ash.destroy(actor: socket.assigns.current_user) do
      :ok ->
        {:noreply,
         socket
         |> put_flash(:info, "Product deleted successfully")
         |> stream_delete(:materials, %{id: id})}

      {:error, _error} ->
        {:noreply, socket |> put_flash(:error, "Failed to delete product.")}
    end
  end

  @impl true
  def handle_info({MicrocraftWeb.ProductLive.FormComponent, {:saved, product}}, socket) do
    {:noreply, stream_insert(socket, :products, product)}
  end
end
