defmodule MicrocraftWeb.OrderLive.Show do
  @moduledoc false
  alias Microcraft.CRM
  alias Microcraft.Catalog
  use MicrocraftWeb, :live_view

  alias Microcraft.Orders

  @impl true
  def render(assigns) do
    ~H"""
    <.header>
      <.breadcrumb>
        <:crumb label="All Orders" path={~p"/backoffice/orders"} current?={false} />
        <:crumb label={@order.id} path={~p"/backoffice/orders/#{@order.id}"} current?={true} />
      </.breadcrumb>

      <:actions>
        <.link patch={~p"/backoffice/orders/#{@order.id}/edit"} phx-click={JS.push_focus()}>
          <.button>Edit order</.button>
        </.link>
      </:actions>
    </.header>

    <div class="mt-4">
      <.tabs id="order-tabs">
        <:tab
          label="Details"
          path={~p"/backoffice/orders/#{@order.id}?page=details"}
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
              {Money.from_float!(@settings.currency, Decimal.to_float(@order.total_cost))}
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
      </.tabs>
    </div>

    <.modal
      :if={@live_action == :edit}
      id="order-modal"
      show
      on_cancel={JS.patch(~p"/backoffice/orders/#{@order.id}")}
    >
      <.live_component
        module={MicrocraftWeb.OrderLive.FormComponent}
        id={(@order && @order.id) || :new}
        current_user={@current_user}
        title={@page_title}
        action={@live_action}
        order={@order}
        products={@products}
        customers={@customers}
        patch={~p"/backoffice/orders"}
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
      Orders.get_order_by_id!(id,
        load: [:total_cost, :items, customer: [:full_name, shipping_address: [:full_address]]]
      )

    page = Map.get(params, "page", "details")

    socket =
      socket
      |> assign(:page_title, page_title(socket.assigns.live_action))
      |> assign(:order, order)
      |> assign(:page, page)

    {:noreply, socket}
  end

  @impl true
  def handle_info(
        {MicrocraftWeb.OrderLive.FormComponentItems, {:saved, _}},
        socket
      ) do
    order =
      Orders.get_order_by_id!(socket.assigns.order.id,
        load: [:items]
      )

    {:noreply,
     socket
     |> put_flash(:info, "Order items updated successfully")
     |> assign(:order, order)
     |> push_event("close-modal", %{id: "order-item-modal"})}
  end

  def handle_info(
        {MicrocraftWeb.OrderLive.FormComponent, {:saved, _}},
        socket
      ) do
    order =
      Orders.get_order_by_id!(socket.assigns.order.id,
        load: [:total_cost, :items, customer: [:full_name, shipping_address: [:full_address]]]
      )

    {:noreply,
     socket
     |> put_flash(:info, "Order updated successfully")
     |> assign(:order, order)}
  end

  defp page_title(:show), do: "Show Order"
  defp page_title(:edit), do: "Edit Order"
end
