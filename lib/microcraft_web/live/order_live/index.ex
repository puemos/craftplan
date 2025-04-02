defmodule MicrocraftWeb.OrderLive.Index do
  @moduledoc false
  use MicrocraftWeb, :live_view

  alias Microcraft.Catalog
  alias Microcraft.CRM
  alias Microcraft.Orders

  @default_filters %{
    "status" => [],
    "payment_status" => [],
    "delivery_date_start" => "",
    "delivery_date_end" => "",
    "customer_name" => ""
  }

  @impl true
  def render(assigns) do
    ~H"""
    <.header>
      <.breadcrumb>
        <:crumb label="All Orders" path={~p"/manage/orders"} current?={true} />
      </.breadcrumb>
      <:actions>
        <.link patch={~p"/manage/orders/new"}>
          <.button>New Order</.button>
        </.link>
      </:actions>
    </.header>

    <form id="filters-form" phx-change="apply_filters" class="mb-6">
      <div class="flex w-full space-x-4">
        <.input
          type="text"
          name="filters[customer_name]"
          id="customer_name"
          value={@filters["customer_name"]}
          label="Customer Name"
          placeholder="Luca Georgino"
        />
        <div class="w-52">
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
              {"In Process", "in_process"},
              {"Ready", "ready"},
              {"Delivered", "delivered"},
              {"Completed", "completed"},
              {"Cancelled", "cancelled"}
            ]}
          />
        </div>
        <div class="w-52">
          <.input
            type="checkdrop"
            name="filters[payment_status][]"
            id="payment_status"
            value={@filters["payment_status"]}
            multiple={true}
            label="Payment"
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
          label="Delivery Start"
        />

        <.input
          type="date"
          name="filters[delivery_date_end]"
          id="delivery_date_end"
          value={@filters["delivery_date_end"]}
          label="Delivery End"
        />
        <div class="mt-8 flex justify-end">
          <.button type="button" phx-click="reset_filters" class="ml-2">
            Reset Filters
          </.button>
        </div>
      </div>
    </form>

    <div class="mb-8">
      <.tabs id="orders-view-tabs">
        <:tab
          label="Table View"
          path={~p"/manage/orders?view=table"}
          selected?={@view_mode == "table"}
        >
          <.table
            id="orders"
            rows={@streams.orders}
            row_click={fn {_id, order} -> JS.navigate(~p"/manage/orders/#{order.reference}") end}
          >
            <:empty>
              <div class="block py-4 pr-6">
                <span>No orders found</span>
              </div>
            </:empty>

            <:col :let={{_id, order}} label="Customer">
              <.link
                class="hover:text-blue-800 hover:underline"
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
        </:tab>
        <:tab
          label="Calendar View"
          path={~p"/manage/orders?view=calendar"}
          selected?={@view_mode == "calendar"}
        >
          <div class="p-4">
            <div class="mb-4 flex justify-end space-x-2">
              <div class="calendar-view-switcher">
                <.button
                  phx-click="switch_calendar_view"
                  phx-value-view="dayGridMonth"
                  size={:sm}
                  variant={if @calendar_view == "dayGridMonth", do: :default, else: :outline}
                >
                  Month
                </.button>
                <.button
                  phx-click="switch_calendar_view"
                  phx-value-view="listMonth"
                  size={:sm}
                  variant={if @calendar_view == "listMonth", do: :default, else: :outline}
                >
                  List
                </.button>
              </div>
            </div>
            <div
              id="orders-calendar"
              class="h-[600px] w-full"
              phx-update="ignore"
              phx-hook="OrderCalendar"
              data-events={Jason.encode!(@calendar_events)}
              data-view={@calendar_view}
            >
            </div>
          </div>
        </:tab>
      </.tabs>
    </div>

    <.modal
      :if={@live_action in [:new, :edit]}
      id="order-modal"
      show
      on_cancel={JS.patch(~p"/manage/orders")}
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
        patch={~p"/manage/orders"}
      />
    </.modal>

    <.modal :if={@event_details} id="event-details-modal" show>
      <.header>
        <h2 class="text-lg font-semibold">{@event_details.title}</h2>
      </.header>
      <div class="py-4">
        <div class="mb-4 grid grid-cols-2 gap-4">
          <div>
            <p class="text-sm font-medium text-gray-500">Start Time</p>
            <p>{format_time(@event_details.start, @time_zone)}</p>
          </div>
          <div>
            <p class="text-sm font-medium text-gray-500">End Time</p>
            <p>{format_time(@event_details.end, @time_zone)}</p>
          </div>
          <div :if={@event_order} class="col-span-2">
            <p class="text-sm font-medium text-gray-500">Customer</p>
            <p :if={@event_order.customer}>{@event_order.customer.full_name}</p>
          </div>
          <div :if={@event_order} class="col-span-2">
            <p class="text-sm font-medium text-gray-500">Status</p>
            <.badge
              :if={@event_order}
              text={@event_order.status}
              colors={[
                {@event_order.status,
                 "#{order_status_color(@event_order.status)} #{order_status_bg(@event_order.status)}"}
              ]}
            />
          </div>
          <div :if={@event_order} class="col-span-2">
            <p class="text-sm font-medium text-gray-500">Payment Status</p>
            <.badge
              :if={@event_order}
              text={"#{emoji_for_payment(@event_order.payment_status)} #{@event_order.payment_status}"}
            />
          </div>
          <div :if={@event_order} class="col-span-2">
            <p class="text-sm font-medium text-gray-500">Total</p>
            <p :if={@event_order}>{format_money(@settings.currency, @event_order.total_cost)}</p>
          </div>
        </div>
      </div>
      <:actions>
        <.button :if={@event_details.url} navigate={@event_details.url} class="mr-2">
          View Order Details
        </.button>
        <.button variant={:outline} phx-click={JS.exec("data-cancel", to: "#event-details-modal")}>
          Close
        </.button>
      </:actions>
    </.modal>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    socket = assign(socket, :filters, @default_filters)

    filter_opts = parse_filters(@default_filters)

    # Get orders without stream option to use for calendar
    orders_for_calendar =
      Orders.list_orders!(
        filter_opts,
        actor: socket.assigns[:current_user],
        load: [:items, :total_cost, customer: [:full_name]]
      )

    # Get orders with stream option for the table
    streamed_orders =
      Orders.list_orders!(
        filter_opts,
        actor: socket.assigns[:current_user],
        stream?: true,
        load: [:items, :total_cost, customer: [:full_name]]
      )

    products =
      Catalog.list_products!(actor: socket.assigns[:current_user])

    customers =
      CRM.list_customers!(actor: socket.assigns[:current_user], load: [:full_name])

    socket =
      socket
      |> assign(:products, products)
      |> assign(:customers, customers)
      # Default view is table
      |> assign(:view_mode, "table")
      # Default calendar view is week
      |> assign(:calendar_view, "dayGridMonth")
      # Initialize empty calendar events
      |> assign(:calendar_events, [])
      # Store orders for calendar
      |> assign(:orders, orders_for_calendar)
      |> assign(:event_details, nil)
      |> assign(:event_order, nil)
      |> stream(:orders, streamed_orders)

    {:ok, socket}
  end

  @impl true
  def handle_params(params, _url, socket) do
    view_mode = Map.get(params, "view", "table")

    # Reload orders to ensure consistency between views
    filter_opts = parse_filters(socket.assigns.filters)

    # Get orders for both views with the current filters
    orders_for_calendar =
      Orders.list_orders!(
        filter_opts,
        actor: socket.assigns[:current_user],
        load: [:items, :total_cost, customer: [:full_name]]
      )

    # Only update the stream if the view mode changed to ensure consistency
    socket =
      if socket.assigns.view_mode == view_mode do
        socket
      else
        streamed_orders =
          Orders.list_orders!(
            filter_opts,
            actor: socket.assigns[:current_user],
            stream?: true,
            load: [:items, :total_cost, customer: [:full_name]]
          )

        stream(socket, :orders, streamed_orders, reset: true)
      end

    # Create calendar events from orders
    calendar_events =
      Enum.map(orders_for_calendar, fn order ->
        # Convert order to calendar event format
        %{
          id: order.reference,
          title: "#{order.customer.full_name} - #{format_reference(order.reference)}",
          start: DateTime.to_iso8601(order.delivery_date),
          # 1 hour duration
          end: order.delivery_date |> DateTime.add(3600, :second) |> DateTime.to_iso8601(),
          color: get_status_color_hex(order.status),
          textColor: "#000"
        }
      end)

    socket =
      socket
      |> assign(:view_mode, view_mode)
      |> assign(:orders, orders_for_calendar)
      |> assign(:calendar_events, calendar_events)

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
  def handle_event("reset_filters", _params, socket) do
    # Reset to default filters
    socket = assign(socket, :filters, @default_filters)

    filter_opts = parse_filters(@default_filters)

    # Get orders with reset filters
    orders_for_calendar =
      Orders.list_orders!(
        filter_opts,
        actor: socket.assigns[:current_user],
        load: [:items, :total_cost, customer: [:full_name]]
      )

    streamed_orders =
      Orders.list_orders!(
        filter_opts,
        actor: socket.assigns[:current_user],
        stream?: true,
        load: [:items, :total_cost, customer: [:full_name]]
      )

    # Update calendar events with reset filters
    calendar_events =
      Enum.map(orders_for_calendar, fn order ->
        %{
          id: order.reference,
          title: "#{order.customer.full_name} - #{format_reference(order.reference)}",
          start: DateTime.to_iso8601(order.delivery_date),
          end: order.delivery_date |> DateTime.add(3600, :second) |> DateTime.to_iso8601(),
          url: "/manage/orders/#{order.reference}",
          color: get_status_color_hex(order.status)
        }
      end)

    socket =
      socket
      |> assign(:orders, orders_for_calendar)
      |> assign(:calendar_events, calendar_events)
      |> stream(:orders, streamed_orders, reset: true)

    {:noreply, socket}
  end

  @impl true
  def handle_event("show_event_modal", event_data, socket) do
    # Find the order associated with this event
    event_order =
      Enum.find(socket.assigns.orders, fn order ->
        order.reference == event_data["eventId"]
      end)

    # Convert string dates to DateTime objects
    start_time =
      case DateTime.from_iso8601(event_data["start"]) do
        {:ok, datetime, _} -> datetime
        _ -> nil
      end

    end_time =
      case DateTime.from_iso8601(event_data["end"]) do
        {:ok, datetime, _} -> datetime
        _ -> nil
      end

    # Structure the event details for the modal
    event_details = %{
      id: event_data["eventId"],
      title: event_data["title"],
      start: start_time,
      end: end_time,
      url: event_data["url"],
      all_day: event_data["allDay"]
    }

    {:noreply, assign(socket, event_details: event_details, event_order: event_order)}
  end

  @impl true
  def handle_event("switch_calendar_view", %{"view" => view}, socket) do
    socket =
      socket
      |> assign(:calendar_view, view)
      |> push_event("update-calendar-view", %{view: view})

    {:noreply, socket}
  end

  @impl true
  def handle_event("apply_filters", %{"filters" => raw_filters}, socket) do
    new_filters = Map.merge(socket.assigns.filters, raw_filters)

    filter_opts = parse_filters(new_filters)

    # Get orders for both calendar and table
    orders_for_calendar =
      Orders.list_orders!(
        filter_opts,
        actor: socket.assigns[:current_user],
        load: [:items, :total_cost, customer: [:full_name]]
      )

    streamed_orders =
      Orders.list_orders!(
        filter_opts,
        actor: socket.assigns[:current_user],
        stream?: true,
        load: [:items, :total_cost, customer: [:full_name]]
      )

    socket =
      socket
      |> assign(:filters, new_filters)
      |> assign(:orders, orders_for_calendar)
      |> stream(:orders, streamed_orders, reset: true)

    # Update calendar events after filtering
    calendar_events =
      Enum.map(orders_for_calendar, fn order ->
        %{
          id: order.reference,
          title: "#{order.customer.full_name} - #{format_reference(order.reference)}",
          start: DateTime.to_iso8601(order.delivery_date),
          end: order.delivery_date |> DateTime.add(3600, :second) |> DateTime.to_iso8601(),
          url: "/manage/orders/#{order.reference}",
          color: get_status_color_hex(order.status)
        }
      end)

    socket = assign(socket, :calendar_events, calendar_events)

    {:noreply, socket}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    case id
         |> Orders.get_order_by_id!()
         |> Ash.destroy(actor: socket.assigns[:current_user]) do
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
    # Update URL to include the view parameter
    {:noreply, push_patch(socket, to: ~p"/manage/orders?view=#{view}")}
  end

  @impl true
  def handle_event(
        "update_date_filters",
        %{"start_date" => start_date, "end_date" => end_date, "view_type" => _view_type},
        socket
      ) do
    # Update the date filters based on calendar navigation
    # For monthly view, use the whole month range
    # For weekly view, use the week range
    # For list view, use the list range

    # Update filters with new date ranges
    new_filters =
      socket.assigns.filters
      |> Map.put("delivery_date_start", start_date)
      |> Map.put("delivery_date_end", end_date)

    filter_opts = parse_filters(new_filters)

    # Get orders for both calendar and table with the new date range
    orders_for_calendar =
      Orders.list_orders!(
        filter_opts,
        actor: socket.assigns[:current_user],
        load: [:items, :total_cost, customer: [:full_name]]
      )

    streamed_orders =
      Orders.list_orders!(
        filter_opts,
        actor: socket.assigns[:current_user],
        stream?: true,
        load: [:items, :total_cost, customer: [:full_name]]
      )

    # Update calendar events based on the new orders
    calendar_events =
      Enum.map(orders_for_calendar, fn order ->
        %{
          id: order.reference,
          title: "#{order.customer.full_name} - #{format_reference(order.reference)}",
          start: DateTime.to_iso8601(order.delivery_date),
          end: order.delivery_date |> DateTime.add(3600, :second) |> DateTime.to_iso8601(),
          url: "/manage/orders/#{order.reference}",
          color: get_status_color_hex(order.status)
        }
      end)

    # Send a JavaScript command to update the calendar with the new events
    socket =
      socket
      |> assign(:filters, new_filters)
      |> assign(:orders, orders_for_calendar)
      |> assign(:calendar_events, calendar_events)
      |> stream(:orders, streamed_orders, reset: true)
      |> push_event("update-calendar", %{events: calendar_events})

    {:noreply, socket}
  end

  @impl true
  def handle_info({MicrocraftWeb.OrderLive.FormComponent, {:saved, order}}, socket) do
    order = Ash.load!(order, [:items, :total_cost, customer: [:full_name]])
    socket = stream_insert(socket, :orders, order)

    # Add the new order to the orders list
    orders = [order | socket.assigns.orders || []]
    socket = assign(socket, :orders, orders)

    # Update calendar events when a new order is added
    calendar_events =
      Enum.map(orders, fn order ->
        %{
          id: order.reference,
          title: "#{order.customer.full_name} - #{format_reference(order.reference)}",
          start: DateTime.to_iso8601(order.delivery_date),
          end: order.delivery_date |> DateTime.add(3600, :second) |> DateTime.to_iso8601(),
          url: "/manage/orders/#{order.reference}",
          color: get_status_color_hex(order.status)
        }
      end)

    socket = assign(socket, :calendar_events, calendar_events)

    {:noreply, socket}
  end

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

  defp emoji_for_payment(:pending), do: "⌛"
  defp emoji_for_payment(:paid), do: "💰"
  defp emoji_for_payment(:to_be_refunded), do: "↩️"
  defp emoji_for_payment(:refunded), do: "✅"
  defp emoji_for_payment(_), do: "❓"

  # Get color hex values for calendar events based on order status
  # Using brighter, more saturated colors for better contrast with black text
  # Darker orange
  defp get_status_color_hex(:unconfirmed), do: "#f97316"
  # Brighter blue
  defp get_status_color_hex(:confirmed), do: "#60a5fa"
  # Brighter purple
  defp get_status_color_hex(:in_process), do: "#a78bfa"
  # Brighter green
  defp get_status_color_hex(:ready), do: "#34d399"
  # Brighter sky blue
  defp get_status_color_hex(:delivered), do: "#38bdf8"
  # Brighter teal
  defp get_status_color_hex(:completed), do: "#2dd4bf"
  # Brighter red
  defp get_status_color_hex(:cancelled), do: "#f87171"
  # Darker gray
  defp get_status_color_hex(_), do: "#6b7280"
end
