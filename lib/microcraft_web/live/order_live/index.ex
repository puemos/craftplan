defmodule MicrocraftWeb.OrderLive.Index do
  @moduledoc false
  use MicrocraftWeb, :live_view

  alias Microcraft.Orders
  alias Microcraft.Orders.Order

  @impl true
  def render(assigns) do
    ~H"""
    <.header>
      Manage your orders
      <:subtitle>
        <.breadcrumb>
          <:crumb label="Orders" path={~p"/backoffice/orders"} current?={true} />
        </.breadcrumb>
      </:subtitle>
      <:actions>
        <.link patch={~p"/backoffice/orders/new"}>
          <.button>New Order</.button>
        </.link>
      </:actions>
    </.header>

    <.table
      id="orders"
      rows={@streams.orders}
      row_click={fn {_id, order} -> JS.navigate(~p"/backoffice/orders/#{order.reference}") end}
    >
      <:col :let={{_id, order}} label="Reference">
        <.kbd>{order.reference}</.kbd>
      </:col>
      <:col :let={{_id, order}} label="Customer">
        {order.customer.name}
      </:col>
      <:col :let={{_id, order}} label="Status">
        <.badge
          text={order.status}
          colors={[
            {order.status, "#{order_status_color(order.status)} #{order_status_bg(order.status)}"}
          ]}
        />
      </:col>
      <:col :let={{_id, order}} label="Payment Status">
        <.badge
          text={order.payment_status}
          colors={[
            {order.payment_status,
             "#{payment_status_color(order.payment_status)} #{payment_status_bg(order.payment_status)}"}
          ]}
        />
      </:col>
      <:col :let={{_id, order}} label="Delivery Date">
        {Calendar.strftime(order.delivery_date, "%Y-%m-%d")}
      </:col>
      <:col :let={{_id, order}} label="Total">
        <%= if order.total_amount do %>
          <%!-- {Number.Currency.number_to_currency(order.total_amount)} --%>
        <% else %>
          -
        <% end %>
      </:col>
      <:action :let={{_id, order}}>
        <.link patch={~p"/backoffice/orders/#{order.reference}/edit"}>Edit</.link>
      </:action>
    </.table>

    <.modal
      :if={@live_action in [:new, :edit]}
      id="order-modal"
      show
      on_cancel={JS.patch(~p"/backoffice/orders")}
    >
      <.live_component
        module={MicrocraftWeb.OrderLive.FormComponent}
        id={@order.id || :new}
        title={@page_title}
        action={@live_action}
        current_user={@current_user}
        order={@order}
        patch={~p"/backoffice/orders"}
      />
    </.modal>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    {:ok, stream(socket, :orders, Orders.list_orders())}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :new, _params) do
    socket
    |> assign(:page_title, "New Order")
    |> assign(:order, %Order{})
  end

  defp apply_action(socket, :edit, %{"reference" => reference}) do
    socket
    |> assign(:page_title, "Edit Order")
    |> assign(:order, Orders.get_order_by_reference!(reference))
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "Orders")
    |> assign(:order, nil)
  end

  @impl true
  def handle_info({MicrocraftWeb.OrderLive.FormComponent, {:saved, order}}, socket) do
    order = Orders.get_order!(order.id)
    {:noreply, stream_insert(socket, :orders, order)}
  end
end
