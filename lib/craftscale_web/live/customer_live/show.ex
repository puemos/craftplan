defmodule CraftScaleWeb.CustomerLive.Show do
  @moduledoc false
  use CraftScaleWeb, :live_view

  alias CraftScale.CRM

  @impl true
  def render(assigns) do
    ~H"""
    <.header>
      <.breadcrumb>
        <:crumb label="All Customers" path={~p"/manage/customers"} current?={false} />
        <:crumb
          label={"#{@customer.full_name}"}
          path={~p"/manage/customers/#{@customer.id}"}
          current?={true}
        />
      </.breadcrumb>

      <:actions>
        <.link patch={~p"/manage/customers/#{@customer.id}/edit"}>
          <.button>Edit customer</.button>
        </.link>
      </:actions>
    </.header>

    <div class="mt-4">
      <.tabs id="customer-tabs">
        <:tab
          label="Details"
          path={~p"/manage/customers/#{@customer.id}?page=details"}
          selected?={@page == "details"}
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
          path={~p"/manage/customers/#{@customer.id}?page=orders"}
          selected?={@page == "orders"}
        >
          <div class="mt-6 space-y-4">
            <div class="flex items-center justify-between">
              <h3 class="text-lg font-semibold">Orders History</h3>
              <.link navigate={~p"/manage/orders/new?customer_id=#{@customer.id}"}>
                <.button>New Order</.button>
              </.link>
            </div>

            <.table
              id="customer_orders"
              rows={@customer.orders}
              row_click={fn order -> JS.navigate(~p"/manage/orders/#{order.id}") end}
            >
              <:col :let={order} label="ID">
                <.kbd>{order.id}</.kbd>
              </:col>
              <:col :let={order} label="Status">
                <.badge
                  text={order.status}
                  colors={[
                    pending: "bg-yellow-100 text-yellow-700",
                    fulfilled: "bg-blue-100 text-blue-700",
                    shipped: "bg-green-100 text-green-700",
                    cancelled: "bg-red-100 text-red-700"
                  ]}
                />
              </:col>

              <:col :let={order} label="Delivery Date">
                {Calendar.strftime(order.delivery_date, "%Y-%m-%d")}
              </:col>
              <:col :let={order} label="Total">
                {format_money(@settings.currency, order.total_cost)}
              </:col>
            </.table>
          </div>
        </:tab>

        <:tab
          label="Statistics"
          path={~p"/manage/customers/#{@customer.id}?page=statistics"}
          selected?={@page == "statistics"}
        >
          <div class="mt-6 space-y-8">
            <div class="grid grid-cols-1 gap-4 sm:grid-cols-3">
              <.stat_card
                title="Total Orders"
                value={@customer.total_orders}
                description="All time orders"
              />

              <.stat_card
                title="Total Spent"
                value={{format_money(@settings.currency, @customer.total_orders_value)}}
                description="All time purchases"
              />
            </div>

            <div class="space-y-4">
              <h3 class="text-lg font-semibold">Recent Activity</h3>
              <div class="space-y-2">
                <%= for order <- @customer.orders do %>
                  <div class="flex items-center justify-between rounded-lg bg-white p-4 shadow">
                    <div class="space-y-1">
                      <div class="text-sm text-gray-500">
                        {Calendar.strftime(order.inserted_at, "%Y-%m-%d %H:%M")}
                      </div>
                      <div class="font-medium">
                        Order {order.id}
                      </div>
                    </div>
                    <div class="flex items-center gap-4">
                      <.badge text={order.status} />
                      <span class="font-medium">
                        {format_money(@settings.currency, order.total_cost)}
                      </span>
                    </div>
                  </div>
                <% end %>
              </div>
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
  def handle_params(%{"id" => id} = params, _, socket) do
    customer =
      CRM.get_customer_by_id!(
        id,
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

    page = Map.get(params, "page", "details")

    {:noreply,
     socket
     |> assign(:page_title, "Customer Details")
     |> assign(:customer, customer)
     |> assign(:page, page)}
  end
end
