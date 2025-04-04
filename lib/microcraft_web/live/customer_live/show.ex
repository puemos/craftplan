defmodule MicrocraftWeb.CustomerLive.Show do
  @moduledoc false
  use MicrocraftWeb, :live_view

  alias Microcraft.CRM

  @impl true
  def render(assigns) do
    ~H"""
    <.header>
      <.breadcrumb>
        <:crumb label="All Customers" path={~p"/manage/customers"} current?={false} />
        <:crumb
          label={"#{@customer.full_name}"}
          path={~p"/manage/customers/#{@customer.reference}"}
          current?={true}
        />
      </.breadcrumb>

      <:actions>
        <.link patch={~p"/manage/customers/#{@customer.reference}/edit"}>
          <.button>Edit customer</.button>
        </.link>
      </:actions>
    </.header>

    <div class="mt-4">
      <.tabs id="customer-tabs">
        <:tab
          label="Details"
          path={~p"/manage/customers/#{@customer.reference}/details"}
          selected?={@live_action == :details || @live_action == :show}
        >
          <div class="mt-8 space-y-8">
            <div class="grid grid-cols-1 gap-8 md:grid-cols-2">
              <.list>
                <:item title="Type"><.badge text={@customer.type} /></:item>
                <:item title="Name">{@customer.full_name}</:item>
                <:item title="Email">{@customer.email}</:item>
                <:item title="Phone">{@customer.phone}</:item>
                <:item title="Billing Address">{@customer.billing_address.full_address}</:item>
                <:item title="Shipping Address">{@customer.shipping_address.full_address}</:item>
              </.list>
            </div>
          </div>
        </:tab>

        <:tab
          label="Orders"
          path={~p"/manage/customers/#{@customer.reference}/orders"}
          selected?={@live_action == :orders}
        >
          <div class="mt-6 space-y-4">
            <div class="flex items-center justify-between">
              <h3 class="text-lg font-semibold">Orders History</h3>
              <.link navigate={~p"/manage/orders/new?customer_id=#{@customer.reference}"}>
                <.button>New Order</.button>
              </.link>
            </div>

            <.table
              id="customer_orders"
              rows={@customer.orders}
              row_click={fn order -> JS.navigate(~p"/manage/orders/#{order.reference}") end}
            >
              <:col :let={order} label="Reference">
                <.kbd>{order.reference}</.kbd>
              </:col>
              <:col :let={order} label="Status">
                <.badge
                  text={order.status}
                  colors={[
                    {order.status,
                     "#{order_status_color(order.status)} #{order_status_bg(order.status)}"}
                  ]}
                />
              </:col>
              <:col :let={order} label="Created at">
                {format_time(order.inserted_at, @time_zone)}
              </:col>
              <:col :let={order} label="Delivery Date">
                {format_time(order.delivery_date, @time_zone)}
              </:col>
              <:col :let={order} label="Total">
                {format_money(@settings.currency, order.total_cost)}
              </:col>
            </.table>
          </div>
        </:tab>

        <:tab
          label="Statistics"
          path={~p"/manage/customers/#{@customer.reference}/statistics"}
          selected?={@live_action == :statistics}
        >
          <div class="mt-6 space-y-8">
            <div class="grid grid-cols-1 gap-4 sm:grid-cols-3">
              <.stat_card title="Total Orders" value={@customer.total_orders} />

              <.stat_card
                title="Total Spent"
                value={format_money(@settings.currency, @customer.total_orders_value)}
              />
            </div>
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
  def handle_params(%{"reference" => reference}, _, socket) do
    customer =
      CRM.get_customer_by_reference!(
        reference,
        actor: socket.assigns.current_user,
        load: [
          :full_name,
          :total_orders_value,
          :total_orders,
          orders: [:total_cost, :total_items],
          billing_address: [:full_address],
          shipping_address: [:full_address]
        ]
      )

    {:noreply,
     socket
     |> assign(:page_title, page_title(socket.assigns.live_action))
     |> assign(:customer, customer)}
  end

  defp page_title(:show), do: "Customer Details"
  defp page_title(:details), do: "Customer Details"
  defp page_title(:orders), do: "Customer Orders"
  defp page_title(:statistics), do: "Customer Statistics"
end
