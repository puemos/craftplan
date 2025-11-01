defmodule CraftplanWeb.OrderLive.Index do
  @moduledoc """
  LiveView for managing orders with table and calendar views.
  Provides filtering, creation, and viewing of orders.
  """
  use CraftplanWeb, :live_view

  import CraftplanWeb.OrderLive.Helpers

  alias Craftplan.Catalog
  alias Craftplan.CRM
  alias Craftplan.Orders
  alias CraftplanWeb.Components.Page
  alias CraftplanWeb.Navigation

  @type filter_options :: %{
          status: list(String.t()) | nil,
          payment_status: list(String.t()) | nil,
          delivery_date_start: DateTime.t() | nil,
          delivery_date_end: DateTime.t() | nil,
          customer_name: String.t() | nil
        }

  @default_filters %{
    "status" => [],
    "payment_status" => [],
    "delivery_date_start" => "",
    "delivery_date_end" => "",
    "customer_name" => ""
  }

  # Calendar event duration in seconds
  @calendar_event_duration 3600

  @impl true
  def render(assigns) do
    assigns =
      assigns
      |> assign_new(:nav_sub_links, fn -> [] end)
      |> assign_new(:breadcrumbs, fn -> [] end)
      |> assign_new(:calendar_event_duration, fn -> @calendar_event_duration end)

    ~H"""
    <Page.page>
      <.header>
        Orders
      </.header>

      <Page.surface>
        <:header>
          <div class="space-y-1">
            <h2 class="text-sm font-semibold text-stone-900">Filter orders</h2>
            <p class="text-sm text-stone-500">
              Narrow the list by customer, fulfillment status, or delivery window.
            </p>
          </div>
        </:header>
        <:actions>
          <Page.filter_reset />
        </:actions>
        <form id="filters-form" phx-change="apply_filters">
          <Page.form_grid columns={4} class="max-w-full">
            <.input
              type="text"
              name="filters[customer_name]"
              id="customer_name"
              value={@filters["customer_name"]}
              label="Customer name"
              placeholder="Luca Georgino"
            />

            <div class="min-w-[12rem]">
              <.input
                label="Status"
                type="checkdrop"
                name="filters[status][]"
                id="status"
                value={@filters["status"]}
                multiple={true}
                options={[
                  {"Unconfirmed", "unconfirmed"},
                  {"Confirmed", "confirmed"},
                  {"In Progress", "in_progress"},
                  {"Ready", "ready"},
                  {"Delivered", "delivered"},
                  {"Completed", "completed"},
                  {"Cancelled", "cancelled"}
                ]}
              />
            </div>

            <div class="min-w-[12rem]">
              <.input
                type="checkdrop"
                name="filters[payment_status][]"
                id="payment_status"
                value={@filters["payment_status"]}
                multiple={true}
                label="Payment status"
                options={[
                  {"Paid", "paid"},
                  {"Pending", "pending"},
                  {"To be Refunded", "to_be_refunded"},
                  {"Refunded", "refunded"}
                ]}
              />
            </div>

            <.input
              type="date"
              name="filters[delivery_date_start]"
              id="delivery_date_start"
              value={@filters["delivery_date_start"]}
              label="Delivery date after"
            />

            <.input
              type="date"
              name="filters[delivery_date_end]"
              id="delivery_date_end"
              value={@filters["delivery_date_end"]}
              label="Delivery date before"
            />
          </Page.form_grid>
        </form>
      </Page.surface>

      <Page.section
        title="Orders overview"
        description="Toggle between table and calendar formats to manage production promises."
      >
        <:actions :if={Enum.any?(@nav_sub_links)}>
          <Page.toggle_bar links={@nav_sub_links} />
        </:actions>

        <Page.surface :if={@view_mode == "table"}>
          <.table
            id="orders"
            rows={@streams.orders}
            row_click={fn {_id, order} -> JS.navigate(~p"/manage/orders/#{order.reference}") end}
          >
            <:empty>
              <div class="rounded-md border border-dashed border-stone-200 bg-stone-50 py-10 text-center text-sm text-stone-500">
                No orders match the current filters.
              </div>
            </:empty>

            <:col :let={{_id, order}} label="Customer">
              <.link
                class="hover:text-primary-600 hover:underline"
                navigate={~p"/manage/customers/#{order.customer.reference}"}
              >
                {order.customer.full_name}
              </.link>
            </:col>

            <:col :let={{_id, order}} label="Reference">
              <.kbd>{format_reference(order.reference)}</.kbd>
            </:col>

            <:col :let={{_id, order}} label="Delivery date">
              {format_time(order.delivery_date, @time_zone)}
            </:col>

            <:col :let={{_id, order}} label="Total cost">
              {format_money(@settings.currency, order.total_cost)}
            </:col>

            <:col :let={{_id, order}} label="Status">
              <.badge
                text={order.status}
                colors={[
                  {order.status,
                   "#{order_status_color(order.status)} #{order_status_bg(order.status)}"}
                ]}
              />
            </:col>

            <:col :let={{_id, order}} label="Payment">
              <.badge text={"#{emoji_for_payment(order.payment_status)} #{order.payment_status}"} />
            </:col>
          </.table>
        </Page.surface>

        <Page.surface
          :if={@view_mode == "calendar"}
          full_bleed
          class="overflow-hidden"
        >
          <:header>
            <div class="text-sm font-medium text-stone-700">
              {format_date(List.first(@days_range), format: "%B %Y")}
            </div>
          </:header>
          <:actions>
            <div class="flex items-center">
              <button
                type="button"
                phx-click="prev_week"
                class="rounded-l-md border border-gray-300 bg-white px-2 py-1 text-sm text-stone-600 transition hover:bg-gray-50"
              >
                <svg
                  xmlns="http://www.w3.org/2000/svg"
                  class="h-4 w-4"
                  fill="none"
                  viewBox="0 0 24 24"
                  stroke="currentColor"
                  stroke-width="2"
                >
                  <path
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    d="M11 17l-5-5m0 0l5-5m-5 5h12"
                  />
                </svg>
              </button>
              <button
                type="button"
                phx-click="today"
                class="border-y border-gray-300 bg-white px-3 py-1 text-xs font-medium uppercase tracking-wide text-stone-600 transition hover:bg-gray-50 disabled:cursor-default disabled:bg-gray-100 disabled:text-gray-400"
              >
                Today
              </button>
              <button
                type="button"
                phx-click="next_week"
                class="rounded-r-md border border-gray-300 bg-white px-2 py-1 text-sm text-stone-600 transition hover:bg-gray-50"
              >
                <svg
                  xmlns="http://www.w3.org/2000/svg"
                  class="h-4 w-4"
                  fill="none"
                  viewBox="0 0 24 24"
                  stroke="currentColor"
                  stroke-width="2"
                >
                  <path stroke-linecap="round" stroke-linejoin="round" d="M13 7l5 5m0 0l-5 5m5-5H6" />
                </svg>
              </button>
            </div>
          </:actions>

          <div class="overflow-x-auto">
            <table class="min-w-[960px] w-full table-fixed border-collapse">
              <thead class="border-stone-200 text-left text-sm leading-6 text-stone-500">
                <tr>
                  <th
                    :for={{day, index} <- Enum.with_index(@days_range |> Enum.take(7))}
                    class={
                      [
                        "w-1/7 border-r border-stone-200 p-0 pt-4 pr-4 pb-4 font-normal last:border-r-0",
                        index > 0 && "pl-4",
                        index > 0 && "border-l",
                        index < 6 && "border-r",
                        is_today?(day) && "bg-indigo-100/50 border-r-indigo-300",
                        is_today?(Date.add(day, 1)) && "border-r-indigo-300"
                      ]
                      |> Enum.filter(& &1)
                      |> Enum.join("  ")
                    }
                  >
                    <div class="flex items-center justify-center">
                      <div class={[
                        "inline-flex items-center justify-center space-x-1 rounded px-2",
                        is_today?(day) && "bg-indigo-500 text-white"
                      ]}>
                        <div>{format_day_name(day)}</div>
                        <div>{format_short_date(day, @time_zone)}</div>
                      </div>
                    </div>
                  </th>
                </tr>
              </thead>
              <tbody>
                <tr class="h-[60vh]">
                  <td
                    :for={{day, index} <- Enum.with_index(@days_range |> Enum.take(7))}
                    class={
                      [
                        "min-h-[200px] w-1/7 overflow-hidden border-t border-stone-200 border-t-stone-200 p-2 align-top",
                        index > 0 && "border-l",
                        index < 6 && "border-r",
                        is_today?(day) && "bg-indigo-100/50 border-r-indigo-300",
                        is_today?(Date.add(day, 1)) && "border-r-indigo-300"
                      ]
                      |> Enum.filter(& &1)
                      |> Enum.join("  ")
                    }
                  >
                    <div class="h-full overflow-y-auto">
                      <div
                        :for={order <- get_orders_for_day(day, @orders)}
                        phx-click="show_event_modal"
                        phx-value-eventId={order.reference}
                        class={[
                          "group relative mb-2 flex cursor-pointer flex-col space-y-1 border bg-white p-1.5 hover:bg-stone-100",
                          (is_today?(day) && "border-stone-300") || "border-stone-200"
                        ]}
                      >
                        <div
                          class={[
                            "absolute top-1 right-1 h-2 w-2 rounded-full",
                            order_dot_status_bg(order.status)
                          ]}
                          title={order.status}
                        >
                        </div>
                        <div class="truncate text-xs font-medium" title={order.customer.full_name}>
                          {order.customer.full_name}
                        </div>
                        <div class="text-xs text-stone-500">
                          {format_hour(order.delivery_date, @time_zone)}
                        </div>
                        <div class="text-xs text-stone-500">
                          {format_money(@settings.currency, order.total_cost)}
                        </div>
                      </div>

                      <div
                        :if={get_orders_for_day(day, @orders) |> Enum.empty?()}
                        class="flex h-full pt-2 text-sm text-stone-400"
                      >
                      </div>
                    </div>
                  </td>
                </tr>
              </tbody>
            </table>
          </div>
        </Page.surface>
      </Page.section>
    </Page.page>

    <.modal
      :if={@live_action in [:new, :edit]}
      id="order-modal"
      title={@page_title}
      max_width="max-w-2xl"
      show
      on_cancel={JS.patch(~p"/manage/orders")}
    >
      <.live_component
        module={CraftplanWeb.OrderLive.FormComponent}
        id={(@order && @order.id) || :new}
        current_user={@current_user}
        title={@page_title}
        action={@live_action}
        order={@order}
        products={@products}
        customers={@customers}
        settings={@settings}
        patch={~p"/manage/orders"}
      />
    </.modal>

    <.modal
      :if={@selected_order != nil}
      id="event-details-modal"
      max_width="max-w-lg"
      title={"#{@selected_order.customer.full_name} - #{format_reference(@selected_order.reference)}"}
      show
      on_cancel={JS.push("close_event_modal")}
    >
      <div class="py-6">
        <div>
          <.list>
            <:item title="Customer">
              {@selected_order.customer.full_name}
            </:item>

            <:item title="Delivery time">
              {format_time(@selected_order.delivery_date, @time_zone)}
            </:item>

            <:item title="Status">
              <.badge
                text={@selected_order.status}
                colors={[
                  {@selected_order.status,
                   "#{order_status_color(@selected_order.status)} #{order_status_bg(@selected_order.status)}"}
                ]}
              />
            </:item>

            <:item title="Payment Status">
              <.badge text={"#{emoji_for_payment(@selected_order.payment_status)} #{@selected_order.payment_status}"} />
            </:item>

            <:item title="Total">
              {format_money(@settings.currency, @selected_order.total_cost)}
            </:item>
          </.list>
        </div>
      </div>

      <div class="flex justify-end space-x-3">
        <.button
          variant={:primary}
          class="mr-2"
          phx-click={JS.navigate(~p"/manage/orders/#{@selected_order.reference}")}
        >
          View Order Details
        </.button>
        <.button variant={:outline} phx-click="close_event_modal">
          Close
        </.button>
      </div>
    </.modal>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    socket = assign(socket, :filters, @default_filters)

    filter_opts = parse_filters(@default_filters)

    {:ok,
     socket
     |> load_initial_data(filter_opts)
     |> assign_initial_view_state()}
  end

  @impl true
  def handle_params(params, _url, socket) do
    view_mode = Map.get(params, "view", "table")

    # Reload orders to ensure consistency between views
    filter_opts = parse_filters(socket.assigns.filters)

    # Get orders for both views with the current filters
    orders_for_calendar = load_orders_for_calendar(socket, filter_opts)

    # Only update the stream if the view mode changed to ensure consistency
    socket =
      if socket.assigns.view_mode == view_mode do
        socket
      else
        streamed_orders = load_streamed_orders(socket, filter_opts)
        stream(socket, :orders, streamed_orders, reset: true)
      end

    # Create calendar events from orders
    calendar_events =
      create_calendar_events(orders_for_calendar, @calendar_event_duration)

    # Calculate days range for calendar
    days_range = calculate_days_range(socket.assigns[:current_week_start])

    socket =
      socket
      |> assign(:view_mode, view_mode)
      |> assign(:orders, orders_for_calendar)
      |> assign(:calendar_events, calendar_events)
      |> assign(:days_range, days_range)
      |> apply_action(socket.assigns.live_action, params)

    {:noreply, Navigation.assign(socket, :orders, order_trail(socket.assigns))}
  end

  @impl true
  def handle_event("reset_filters", _params, socket) do
    # Reset to default filters
    socket = assign(socket, :filters, @default_filters)
    filter_opts = parse_filters(@default_filters)

    orders_for_calendar = load_orders_for_calendar(socket, filter_opts)
    streamed_orders = load_streamed_orders(socket, filter_opts)

    calendar_events =
      create_calendar_events(orders_for_calendar, @calendar_event_duration)

    socket =
      socket
      |> assign(:orders, orders_for_calendar)
      |> assign(:calendar_events, calendar_events)
      |> stream(:orders, streamed_orders, reset: true)

    {:noreply, socket}
  end

  @impl true
  def handle_event("prev_week", _params, socket) do
    # Move the date range backward by 7 days
    new_start = Date.add(List.first(socket.assigns.days_range), -7)
    days_range = date_range(new_start)

    filter_opts = parse_filters(socket.assigns.filters)
    orders_for_calendar = load_orders_for_calendar(socket, filter_opts)

    {:noreply,
     socket
     |> assign(:current_week_start, new_start)
     |> assign(:days_range, days_range)
     |> assign(:orders, orders_for_calendar)}
  end

  @impl true
  def handle_event("next_week", _params, socket) do
    # Move the date range forward by 7 days
    new_start = Date.add(List.first(socket.assigns.days_range), 7)
    days_range = date_range(new_start)

    filter_opts = parse_filters(socket.assigns.filters)
    orders_for_calendar = load_orders_for_calendar(socket, filter_opts)

    {:noreply,
     socket
     |> assign(:current_week_start, new_start)
     |> assign(:days_range, days_range)
     |> assign(:orders, orders_for_calendar)}
  end

  @impl true
  def handle_event("today", _params, socket) do
    # Reset to current day and forward
    days_range = calculate_days_range()

    filter_opts = parse_filters(socket.assigns.filters)
    orders_for_calendar = load_orders_for_calendar(socket, filter_opts)

    {:noreply,
     socket
     |> assign(:current_week_start, nil)
     |> assign(:days_range, days_range)
     |> assign(:orders, orders_for_calendar)}
  end

  @impl true
  def handle_event("show_event_modal", %{"eventid" => order_reference}, socket) do
    selected_order =
      Enum.find(socket.assigns.orders, fn order -> order.reference == order_reference end)

    {:noreply, assign(socket, selected_order: selected_order)}
  end

  @impl true
  def handle_event("close_event_modal", _params, socket) do
    {:noreply, assign(socket, selected_order: nil)}
  end

  @impl true
  def handle_event("apply_filters", %{"filters" => raw_filters}, socket) do
    new_filters = Map.merge(socket.assigns.filters, raw_filters)
    filter_opts = parse_filters(new_filters)

    orders_for_calendar = load_orders_for_calendar(socket, filter_opts)
    streamed_orders = load_streamed_orders(socket, filter_opts)

    calendar_events =
      create_calendar_events(orders_for_calendar, @calendar_event_duration)

    {:noreply,
     socket
     |> assign(:filters, new_filters)
     |> assign(:orders, orders_for_calendar)
     |> assign(:calendar_events, calendar_events)
     |> stream(:orders, streamed_orders, reset: true)}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    order = Orders.get_order_by_id!(id, actor: socket.assigns[:current_user])

    case Ash.destroy(order, actor: socket.assigns[:current_user]) do
      :ok ->
        {:noreply,
         socket
         |> put_flash(:info, "Order deleted successfully")
         |> stream_delete(:orders, %{id: id})}

      {:error, _error} ->
        {:noreply, put_flash(socket, :error, "Failed to delete order.")}
    end
  end

  @impl true
  def handle_event("change-view", %{"view" => view}, socket) do
    {:noreply, push_patch(socket, to: ~p"/manage/orders?view=#{view}")}
  end

  @impl true
  def handle_event(
        "update_date_filters",
        %{"start_date" => start_date, "end_date" => end_date, "view_type" => _view_type},
        socket
      ) do
    # Update filters with new date ranges
    new_filters =
      socket.assigns.filters
      |> Map.put("delivery_date_start", start_date)
      |> Map.put("delivery_date_end", end_date)

    filter_opts = parse_filters(new_filters)

    orders_for_calendar = load_orders_for_calendar(socket, filter_opts)
    streamed_orders = load_streamed_orders(socket, filter_opts)

    calendar_events =
      create_calendar_events(orders_for_calendar, @calendar_event_duration)

    {:noreply,
     socket
     |> assign(:filters, new_filters)
     |> assign(:orders, orders_for_calendar)
     |> assign(:calendar_events, calendar_events)
     |> stream(:orders, streamed_orders, reset: true)
     |> push_event("update-calendar", %{events: calendar_events})}
  end

  @impl true
  def handle_info({CraftplanWeb.OrderLive.FormComponent, {:saved, order}}, socket) do
    order =
      Ash.load!(order, [:items, :total_cost, customer: [:full_name]], actor: socket.assigns[:current_user])

    orders = [order | socket.assigns.orders || []]
    calendar_events = create_calendar_events(orders, @calendar_event_duration)

    {:noreply,
     socket
     |> stream_insert(:orders, order)
     |> assign(:orders, orders)
     |> assign(:calendar_events, calendar_events)}
  end

  # Private helper functions

  defp load_initial_data(socket, filter_opts) do
    orders_for_calendar = load_orders_for_calendar(socket, filter_opts)
    streamed_orders = load_streamed_orders(socket, filter_opts)
    products = Catalog.list_products!(actor: socket.assigns[:current_user])
    customers = CRM.list_customers!(actor: socket.assigns[:current_user], load: [:full_name])
    days_range = calculate_days_range()

    socket
    |> assign(:products, products)
    |> assign(:customers, customers)
    |> assign(:orders, orders_for_calendar)
    |> assign(:days_range, days_range)
    |> assign(:current_week_start, nil)
    |> stream(:orders, streamed_orders)
  end

  defp assign_initial_view_state(socket) do
    socket
    |> assign(:view_mode, "table")
    |> assign(:calendar_events, [])
    |> assign(:selected_order, nil)
  end

  defp load_orders_for_calendar(socket, filter_opts) do
    Orders.list_orders!(
      filter_opts,
      actor: socket.assigns[:current_user],
      load: [:items, :total_cost, customer: [:full_name], items: [product: [:name]]]
    )
  end

  defp load_streamed_orders(socket, filter_opts) do
    Orders.list_orders!(
      filter_opts,
      actor: socket.assigns[:current_user],
      stream?: true,
      load: [:items, :total_cost, customer: [:full_name], items: [product: [:name]]]
    )
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

  defp order_trail(%{live_action: :new}), do: [Navigation.root(:orders), Navigation.page(:orders, :new)]

  defp order_trail(_), do: [Navigation.root(:orders)]

  @spec parse_filters(map()) :: filter_options()
  defp parse_filters(filters) do
    %{
      status: parse_list(filters["status"]),
      payment_status: parse_list(filters["payment_status"]),
      delivery_date_start: parse_date(filters["delivery_date_start"], ~T[00:00:00]),
      delivery_date_end: parse_date(filters["delivery_date_end"], ~T[23:59:59]),
      customer_name: filters["customer_name"]
    }
  end

  defp parse_list([]), do: nil
  defp parse_list(nil), do: nil
  defp parse_list(list) when is_list(list), do: list
  defp parse_list(value), do: [value]

  defp parse_date("", _time), do: nil

  defp parse_date(date_str, time) do
    case Date.from_iso8601(date_str) do
      {:ok, date} -> DateTime.new!(date, time, "Etc/UTC")
      _ -> nil
    end
  end

  # Helper functions for the calendar view
  defp calculate_days_range(start_date \\ nil) do
    start_date = start_date || beginning_of_week(Date.utc_today())
    date_range(start_date)
  end

  defp beginning_of_week(date) do
    Date.add(date, -(Date.day_of_week(date) - 1))
  end

  defp get_orders_for_day(day, orders) do
    Enum.filter(orders, fn order ->
      delivery_date = DateTime.to_date(order.delivery_date)
      Date.compare(delivery_date, day) == :eq
    end)
  end
end
