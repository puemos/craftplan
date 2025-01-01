defmodule MicrocraftWeb.OrderLive.Index do
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
        <:crumb label="All Orders" path={~p"/backoffice/orders"} current?={true} />
      </.breadcrumb>

      <:actions>
        <.link patch={~p"/backoffice/orders/new"}>
          <.button>New Order</.button>
        </.link>
      </:actions>
    </.header>

    <.table
      id="orders"
      rows={@streams.orders}
      row_click={fn {_id, order} -> JS.navigate(~p"/backoffice/orders/#{order.id}") end}
    >
      <:empty>
        <div class="block py-4 pr-6">
          <span class={["relative"]}>
            No orders found
          </span>
        </div>
      </:empty>
      <%!-- <:col :let={{_id, order}} label="ID">{order.id}</:col> --%>
      <:col :let={{_id, order}} label="Customer">{order.customer.full_name}</:col>
      <:col :let={{_id, order}} label="Delivery date">{DateTime.to_string(order.delivery_date)}</:col>
      <:col :let={{_id, order}} label="Total cost">
        {Money.from_float!(@settings.currency, Decimal.to_float(order.total_cost))}
      </:col>
      <:col :let={{_id, order}} label="Status">
        <.badge text={order.status} />
      </:col>
    </.table>

    <.modal
      :if={@live_action in [:new, :edit]}
      id="order-modal"
      show
      on_cancel={JS.patch(~p"/backoffice/orders")}
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
        settings={@settings}
        patch={~p"/backoffice/orders"}
      />
    </.modal>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    orders =
      Orders.list_orders!(
        actor: socket.assigns[:current_user],
        stream?: true,
        load: [:items, :total_cost, customer: [:full_name]]
      )

    dbg(orders)

    products =
      Catalog.list_products!(actor: socket.assigns[:current_user])

    customers =
      CRM.list_customers!(actor: socket.assigns[:current_user], load: [:full_name])

    time_zone = get_connect_params(socket)["timeZone"]

    {:ok,
     socket
     |> assign(products: products, customers: customers, time_zone: time_zone)
     |> stream(:orders, orders)}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :new, _params) do
    socket
    |> assign(:page_title, "New Order")
    |> assign(:order, nil)
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "Orders")
    |> assign(:order, nil)
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    case Orders.get_order_by_id!(id) |> Ash.destroy(actor: socket.assigns.current_user) do
      :ok ->
        {:noreply,
         socket
         |> put_flash(:info, "Order deleted successfully")
         |> stream_delete(:materials, %{id: id})}

      {:error, _error} ->
        {:noreply, socket |> put_flash(:error, "Failed to delete order.")}
    end
  end

  @impl true
  def handle_info({MicrocraftWeb.OrderLive.FormComponent, {:saved, order}}, socket) do
    order = Ash.load!(order, [:items, :total_cost, customer: [:full_name]])

    {:noreply, stream_insert(socket, :orders, order)}
  end
end
