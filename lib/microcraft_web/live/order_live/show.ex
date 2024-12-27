defmodule MicrocraftWeb.OrderLive.Show do
  @moduledoc false
  use MicrocraftWeb, :live_view

  import MicrocraftWeb.OrderLive.Helpers

  alias Microcraft.Orders

  @impl true
  def render(assigns) do
    ~H"""
    <.header>
      {@order.customer.name}, {Calendar.strftime(@order.delivery_date, "%Y-%m-%d")}
      <:subtitle>
        <.breadcrumb>
          <:crumb label="Orders" path={~p"/backoffice/orders"} current?={false} />
          <:crumb
            label={@order.reference}
            path={~p"/backoffice/orders/#{@order.reference}"}
            current?={true}
          />
        </.breadcrumb>
      </:subtitle>
      <:actions>
        <.link patch={~p"/backoffice/orders/#{@order.reference}/edit"}>
          <.button>Edit order</.button>
        </.link>
      </:actions>
    </.header>

    <div class="mt-4">
      <.tabs id="order-tabs">
        <:tab
          label="Details"
          path={~p"/backoffice/orders/#{@order.reference}?page=details"}
          selected?={@page == "details"}
        >
          <div class="mt-8 space-y-8">
            <div class="grid grid-cols-1 gap-8 md:grid-cols-2">
              <.list>
                <:item title="Status">
                  <.badge
                    text={@order.status}
                    colors={[
                      {@order.status,
                       "#{order_status_color(@order.status)} #{order_status_bg(@order.status)}"}
                    ]}
                  />
                </:item>
                <:item title="Customer">
                  <.link navigate={~p"/backoffice/customers/#{@order.customer}"}>
                    {@order.customer.name}
                  </.link>
                </:item>
                <:item title="Payment Method">
                  <span class="capitalize">{format_label(@order.payment_method)}</span>
                </:item>
                <:item title="Payment Status">
                  <.badge
                    text={@order.payment_status}
                    colors={[
                      {@order.payment_status,
                       "#{payment_status_color(@order.payment_status)} #{payment_status_bg(@order.payment_status)}"}
                    ]}
                  />
                </:item>
                <:item title="Delivery Date">
                  {Calendar.strftime(@order.delivery_date, "%Y-%m-%d")}
                </:item>
                <:item title="Total Amount">
                  <%= if @order.total_amount do %>
                    <%!-- {Number.Currency.number_to_currency(@order.total_amount)} --%>
                  <% else %>
                    -
                  <% end %>
                </:item>
              </.list>

              <.list>
                <:item title="Delivery Address">
                  <div class="space-y-1">
                    <div>{@order.delivery_address.street}</div>
                    <div>{@order.delivery_address.city}</div>
                    <div>{@order.delivery_address.postal_code}</div>
                    <div>{@order.delivery_address.country}</div>
                  </div>
                </:item>
                <:item title="Notes">
                  {@order.notes || "-"}
                </:item>
              </.list>
            </div>

            <%= if @order.status not in [:completed, :cancelled] do %>
              <div class="mt-6 space-y-6">
                <div>
                  <h3 class="mb-4 text-lg font-semibold">Actions</h3>
                  <div class="flex gap-4">
                    <%= for status <- available_status_transitions(@order.status) do %>
                      <.button phx-click="change_status" phx-value-status={status} class="capitalize">
                        Move to {format_label(status)}
                      </.button>
                    <% end %>
                    <%= case @order.payment_status do %>
                      <% :pending -> %>
                        <.button phx-click="update_payment_status" phx-value-status="paid">
                          Mark as Paid
                        </.button>
                      <% :paid -> %>
                        <.button phx-click="update_payment_status" phx-value-status="refunded">
                          Issue Refund
                        </.button>
                      <% :refunded -> %>
                        <div class="text-sm text-gray-600">
                          Payment has been refunded. No further actions available.
                        </div>
                    <% end %>
                  </div>
                </div>
              </div>
            <% end %>
          </div>
        </:tab>

        <:tab
          label="Items"
          path={~p"/backoffice/orders/#{@order.reference}?page=items"}
          selected?={@page == "items"}
        >
          <div class="mt-6 space-y-4">
            <.table id="order_items" rows={@order.order_items}>
              <:col :let={item} label="Product">
                <.link navigate={~p"/backoffice/products/#{item.product}"}>
                  {item.product.name}
                </.link>
              </:col>
              <:col :let={item} label="Quantity">
                {item.quantity} {item.unit_type}
              </:col>
              <:col :let={item} label="Unit Price">
                <%!-- {Number.Currency.number_to_currency(item.unit_price)} --%>
              </:col>
              <:col :let={item} label="Total">
                <%!-- {Number.Currency.number_to_currency(item.total_price)} --%>
              </:col>
            </.table>
          </div>
        </:tab>
      </.tabs>
    </div>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def handle_params(%{"reference" => reference} = params, _, socket) do
    order = Orders.get_order_by_reference!(reference)
    page = Map.get(params, "page", "details")

    {:noreply,
     socket
     |> assign(:page_title, "Order #{order.reference}")
     |> assign(:order, order)
     |> assign(:page, page)}
  end

  @impl true
  def handle_event("change_status", %{"status" => new_status}, socket) do
    case Orders.update_order_status(socket.assigns.order, String.to_existing_atom(new_status)) do
      {:ok, updated_order} ->
        {:noreply,
         socket
         |> put_flash(:info, "Order status updated successfully")
         |> assign(:order, updated_order)}

      {:error, changeset} ->
        dbg(changeset)

        {:noreply, put_flash(socket, :error, "Unable to update order status")}
    end
  end

  def handle_event("update_payment_status", %{"status" => new_status}, socket) do
    order = socket.assigns.order

    case Orders.update_order_payment_status(order, String.to_existing_atom(new_status)) do
      {:ok, updated_order} ->
        {:noreply,
         socket
         |> put_flash(:info, "Payment status updated successfully")
         |> assign(:order, updated_order)}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Unable to update payment status")}
    end
  end
end
