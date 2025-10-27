defmodule CraftplanWeb.CustomerLive.Show do
  @moduledoc false
  use CraftplanWeb, :live_view

  alias CraftplanWeb.Navigation
  alias Craftplan.CRM

  @impl true
  def render(assigns) do
    assigns =
      assign_new(assigns, :breadcrumbs, fn -> [] end)

    ~H"""
    <.header>
      {@customer.full_name}
    </.header>

    <.sub_nav links={@tabs_links} />

    <div class="p mt-4 space-y-6">
      <.tabs_content :if={@live_action in [:details, :show]}>
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
      </.tabs_content>

      <.tabs_content :if={@live_action == :orders}>
        <div class="mt-6 space-y-4">
          <div class="flex items-center justify-between">
            <h3 class="text-lg font-semibold">Orders History</h3>
            <.link navigate={~p"/manage/orders/new?customer_id=#{@customer.reference}"}>
              <.button variant={:primary}>New Order</.button>
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
      </.tabs_content>

      <.tabs_content :if={@live_action == :statistics}>
        <div class="mt-6 space-y-8">
          <div class="grid grid-cols-1 gap-4 sm:grid-cols-3">
            <.stat_card title="Total Orders" value={@customer.total_orders} />

            <.stat_card
              title="Total Spent"
              value={format_money(@settings.currency, @customer.total_orders_value)}
            />
          </div>
        </div>
      </.tabs_content>
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

    live_action = socket.assigns.live_action

    tabs_links = [
      %{
        label: "Details",
        navigate: ~p"/manage/customers/#{customer.reference}/details",
        active: live_action in [:details, :show]
      },
      %{
        label: "Orders",
        navigate: ~p"/manage/customers/#{customer.reference}/orders",
        active: live_action == :orders
      },
      %{
        label: "Statistics",
        navigate: ~p"/manage/customers/#{customer.reference}/statistics",
        active: live_action == :statistics
      }
    ]

    socket =
      socket
      |> assign(:page_title, page_title(live_action))
      |> assign(:customer, customer)
      |> assign(:tabs_links, tabs_links)

    {:noreply, Navigation.assign(socket, :customers, customer_trail(customer, live_action))}
  end

  defp page_title(:show), do: "Customer Details"
  defp page_title(:details), do: "Customer Details"
  defp page_title(:orders), do: "Customer Orders"
  defp page_title(:statistics), do: "Customer Statistics"

  defp customer_trail(customer, :orders) do
    [
      Navigation.root(:customers),
      Navigation.resource(:customer, customer),
      Navigation.page(:customers, :customer_orders, customer)
    ]
  end

  defp customer_trail(customer, :statistics) do
    [
      Navigation.root(:customers),
      Navigation.resource(:customer, customer),
      Navigation.page(:customers, :customer_statistics, customer)
    ]
  end

  defp customer_trail(customer, _), do: [Navigation.root(:customers), Navigation.resource(:customer, customer)]
end
