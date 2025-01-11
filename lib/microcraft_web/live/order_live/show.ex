defmodule CraftScaleWeb.OrderLive.Show do
  @moduledoc false
  use CraftScaleWeb, :live_view

  alias CraftScale.Catalog
  alias CraftScale.CRM
  alias CraftScale.Orders

  @default_order_load [
    :total_cost,
    items: [:cost, :product],
    customer: [:full_name, shipping_address: [:full_address]]
  ]

  @impl true
  def render(assigns) do
    ~H"""
    <.header>
      <.breadcrumb>
        <:crumb label="All Orders" path={~p"/manage/orders"} current?={false} />
        <:crumb label={@order.id} path={~p"/manage/orders/#{@order.id}"} current?={true} />
      </.breadcrumb>

      <:actions>
        <.link patch={~p"/manage/orders/#{@order.id}/edit"} phx-click={JS.push_focus()}>
          <.button>Edit order</.button>
        </.link>
      </:actions>
    </.header>

    <div class="mt-4">
      <.tabs id="order-tabs">
        <:tab
          label="Details"
          path={~p"/manage/orders/#{@order.id}?page=details"}
          selected?={@page == "details"}
        >
          <.list>
            <:item title="Status">
              <.badge
                text={Atom.to_string(@order.status)}
                colors={[
                  {@order.status,
                   "#{order_status_color(@order.status)} #{order_status_bg(@order.status)}"}
                ]}
              />
            </:item>

            <:item title="Customer">{@order.customer.full_name}</:item>
            <:item title="Shipping Address">{@order.customer.shipping_address.full_address}</:item>

            <:item title="Total">
              {format_money(@settings.currency, @order.total_cost)}
            </:item>

            <%!-- <:item title="Payment Status">
              {@order.payment_status}
            </:item> --%>

            <:item title="Delivery Date">
              {@order.delivery_date}
            </:item>

            <:item title="Created At">
              {@order.inserted_at}
            </:item>
          </.list>
        </:tab>

        <:tab
          label="Items"
          path={~p"/manage/orders/#{@order.id}?page=items"}
          selected?={@page == "items"}
        >
          <.table id="order-items" rows={@order.items}>
            <:col :let={item} label="Product">{item.product.name}</:col>
            <:col :let={item} label="Quantity">{item.quantity}</:col>
            <:col :let={item} label="Unit Price">
              {format_money(@settings.currency, item.product.price)}
            </:col>
            <:col :let={item} label="Total">
              {format_money(@settings.currency, item.cost)}
            </:col>
          </.table>
        </:tab>
      </.tabs>
    </div>

    <.modal
      :if={@live_action == :edit}
      id="order-modal"
      show
      on_cancel={JS.patch(~p"/manage/orders/#{@order.id}")}
    >
      <.live_component
        module={CraftScaleWeb.OrderLive.FormComponent}
        id={(@order && @order.id) || :new}
        current_user={@current_user}
        title={@page_title}
        action={@live_action}
        order={@order}
        products={@products}
        customers={@customers}
        settings={@settings}
        patch={~p"/manage/orders/#{@order.id}"}
      />
    </.modal>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    products =
      Catalog.list_products!(actor: socket.assigns[:current_user])

    customers =
      CRM.list_customers!(actor: socket.assigns[:current_user], load: [:full_name])

    {:ok,
     assign(socket,
       page: "details",
       products: products,
       customers: customers
     )}
  end

  @impl true
  def handle_params(%{"id" => id} = params, _, socket) do
    order =
      Orders.get_order_by_id!(id, load: @default_order_load)

    page = Map.get(params, "page", "details")

    socket =
      socket
      |> assign(:page_title, page_title(socket.assigns.live_action))
      |> assign(:order, order)
      |> assign(:page, page)

    {:noreply, socket}
  end

  @impl true
  def handle_info({CraftScaleWeb.OrderLive.FormComponentItems, {:saved, _}}, socket) do
    order =
      Orders.get_order_by_id!(socket.assigns.order.id, load: @default_order_load)

    {:noreply,
     socket
     |> put_flash(:info, "Order items updated successfully")
     |> assign(:order, order)
     |> push_event("close-modal", %{id: "order-item-modal"})}
  end

  def handle_info({CraftScaleWeb.OrderLive.FormComponent, {:saved, _}}, socket) do
    order =
      Orders.get_order_by_id!(socket.assigns.order.id, load: @default_order_load)

    {:noreply,
     socket
     |> put_flash(:info, "Order updated successfully")
     |> assign(:order, order)}
  end

  defp page_title(:show), do: "Show Order"
  defp page_title(:edit), do: "Edit Order"
end
