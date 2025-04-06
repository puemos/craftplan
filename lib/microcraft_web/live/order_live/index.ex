defmodule MicrocraftWeb.OrderLive.Index do
  @moduledoc """
  LiveView for managing orders with table and calendar views.
  Provides filtering, creation, and viewing of orders.
  """
  use MicrocraftWeb, :live_view

  import MicrocraftWeb.OrderLive.Helpers

  alias Microcraft.Catalog
  alias Microcraft.CRM
  alias Microcraft.Orders

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
    assigns = assign_new(assigns, :calendar_event_duration, fn -> @calendar_event_duration end)

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
          <div
            id="orders-calendar"
            class="w-full"
            phx-update="ignore"
            phx-hook="OrderCalendar"
            data-events={Jason.encode!(@calendar_events)}
            data-view={@calendar_view}
          >
          </div>
        </:tab>
        <:tab
          label="Kanban View"
          path={~p"/manage/orders?view=kanban"}
          selected?={@view_mode == "kanban"}
        >
          <div class="mb-4 flex items-center justify-between">
            <div class="flex space-x-4">
              <div class="inline-flex items-center rounded-md shadow-sm">
                <button
                  phx-click="switch_kanban_mode"
                  phx-value-mode="order"
                  class={"#{if @kanban_mode == "order", do: "border-blue-500 bg-blue-50 text-blue-600", else: "border-gray-300 bg-white text-gray-700 hover:bg-gray-50"} rounded-l-md border px-4 py-2 text-sm font-medium"}
                >
                  By Order Status
                </button>
                <button
                  phx-click="switch_kanban_mode"
                  phx-value-mode="product"
                  class={"#{if @kanban_mode == "product", do: "border-blue-500 bg-blue-50 text-blue-600", else: "border-gray-300 bg-white text-gray-700 hover:bg-gray-50"} rounded-r-md border border-l-0 px-4 py-2 text-sm font-medium"}
                >
                  By Product
                </button>
              </div>
            </div>
          </div>

          <div class="overflow-x-auto pb-4">
            <div class="inline-flex min-w-full space-x-4">
              <%= if @kanban_mode == "order" do %>
                <%= for {status, orders} <- group_orders_by_status(@orders) do %>
                  <div class="w-80 flex-shrink-0">
                    <div class={"#{status_color_class(status)} rounded-t-md p-3"}>
                      <h3 class="font-medium capitalize text-gray-900">
                        {status} ({length(orders)})
                      </h3>
                    </div>
                    <div class="min-h-[30rem] h-full rounded-b-md bg-gray-50 p-2 shadow-md">
                      <%= for order <- orders do %>
                        <div
                          class="mb-2 cursor-pointer rounded-md bg-white p-3 shadow hover:shadow-md"
                          phx-click={JS.navigate(~p"/manage/orders/#{order.reference}")}
                        >
                          <div class="flex items-start justify-between">
                            <div>
                              <h4 class="font-medium">{order.customer.full_name}</h4>
                              <p class="text-sm text-gray-500">{format_reference(order.reference)}</p>
                            </div>
                            <.badge text={"#{emoji_for_payment(order.payment_status)} #{order.payment_status}"} />
                          </div>
                          <div class="mt-2 text-sm text-gray-700">
                            <p>Due: {format_time(order.delivery_date, @time_zone)}</p>
                            <p class="font-medium">
                              {format_money(@settings.currency, order.total_cost)}
                            </p>
                          </div>
                          <%= if order.items && length(order.items) > 0 do %>
                            <div class="mt-2 border-t pt-2">
                              <p class="mb-1 text-xs text-gray-500">Items:</p>
                              <%= for item <- Enum.take(order.items, 2) do %>
                                <div class="flex justify-between text-xs">
                                  <span>{item.quantity}x {item.product.name}</span>
                                  <span>{format_money(@settings.currency, item.unit_price)}</span>
                                </div>
                              <% end %>
                              <%= if length(order.items) > 2 do %>
                                <p class="mt-1 text-xs text-gray-500">
                                  + {length(order.items) - 2} more items
                                </p>
                              <% end %>
                            </div>
                          <% end %>
                        </div>
                      <% end %>
                    </div>
                  </div>
                <% end %>
              <% else %>
                <%= for {product_name, orders} <- group_orders_by_product(@orders) do %>
                  <div class="w-80 flex-shrink-0">
                    <div class="rounded-t-md bg-indigo-50 p-3">
                      <h3 class="font-medium text-gray-900">
                        {product_name} ({length(orders)})
                      </h3>
                    </div>
                    <div class="min-h-[30rem] h-full rounded-b-md bg-gray-50 p-2 shadow-md">
                      <%= for {order, items} <- orders do %>
                        <div
                          class="mb-2 cursor-pointer rounded-md bg-white p-3 shadow hover:shadow-md"
                          phx-click={JS.navigate(~p"/manage/orders/#{order.reference}")}
                        >
                          <div class="flex items-start justify-between">
                            <div>
                              <h4 class="font-medium">{order.customer.full_name}</h4>
                              <p class="text-sm text-gray-500">{format_reference(order.reference)}</p>
                            </div>
                            <.badge
                              text={order.status}
                              colors={[
                                {order.status,
                                 "#{order_status_color(order.status)} #{order_status_bg(order.status)}"}
                              ]}
                            />
                          </div>
                          <div class="mt-2 text-sm">
                            <div class="border-l-4 border-indigo-500 pl-2">
                              <%= for item <- items do %>
                                <div class="flex justify-between">
                                  <span>{item.quantity}x {item.product.name}</span>
                                  <span>{format_money(@settings.currency, item.unit_price)}</span>
                                </div>
                              <% end %>
                            </div>
                          </div>
                          <div class="mt-2 text-xs text-gray-500">
                            <p>Due: {format_time(order.delivery_date, @time_zone)}</p>
                          </div>
                        </div>
                      <% end %>
                    </div>
                  </div>
                <% end %>
              <% end %>
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

    <.modal
      :if={@selected_order_reference != nil}
      id="event-details-modal"
      show
      on_cancel={JS.push("close_event_modal")}
    >
      <.header>
        <h2 class="text-lg font-medium leading-6">
          <%= if order = get_selected_order(@orders, @selected_order_reference) do %>
            {order.customer.full_name} - {format_reference(order.reference)}
          <% end %>
        </h2>
      </.header>

      <div class="py-6">
        <div class="">
          <%= if order = get_selected_order(@orders, @selected_order_reference) do %>
            <.list>
              <:item title="Start Time">
                {format_time(order.delivery_date, @time_zone)}
              </:item>

              <:item title="End Time">
                {format_time(
                  DateTime.add(order.delivery_date, @calendar_event_duration, :second),
                  @time_zone
                )}
              </:item>

              <:item title="Customer">
                {order.customer.full_name}
              </:item>

              <:item title="Status">
                <.badge
                  text={order.status}
                  colors={[
                    {order.status,
                     "#{order_status_color(order.status)} #{order_status_bg(order.status)}"}
                  ]}
                />
              </:item>

              <:item title="Payment Status">
                <.badge text={"#{emoji_for_payment(order.payment_status)} #{order.payment_status}"} />
              </:item>

              <:item title="Total">
                {format_money(@settings.currency, order.total_cost)}
              </:item>
            </.list>
          <% end %>
        </div>
      </div>

      <div class="flex justify-end space-x-3">
        <.button class="mr-2" phx-click={JS.navigate(~p"/manage/orders/#{@selected_order_reference}")}>
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
    calendar_events = create_calendar_events(orders_for_calendar)

    socket =
      socket
      |> assign(:view_mode, view_mode)
      |> assign(:orders, orders_for_calendar)
      |> assign(:calendar_events, calendar_events)

    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  @impl true
  def handle_event("reset_filters", _params, socket) do
    # Reset to default filters
    socket = assign(socket, :filters, @default_filters)
    filter_opts = parse_filters(@default_filters)

    orders_for_calendar = load_orders_for_calendar(socket, filter_opts)
    streamed_orders = load_streamed_orders(socket, filter_opts)
    calendar_events = create_calendar_events(orders_for_calendar)

    socket =
      socket
      |> assign(:orders, orders_for_calendar)
      |> assign(:calendar_events, calendar_events)
      |> stream(:orders, streamed_orders, reset: true)

    {:noreply, socket}
  end

  @impl true
  def handle_event("show_event_modal", %{"eventId" => order_reference}, socket) do
    {:noreply, assign(socket, :selected_order_reference, order_reference)}
  end

  @impl true
  def handle_event("close_event_modal", _params, socket) do
    {:noreply, assign(socket, :selected_order_reference, nil)}
  end

  @impl true
  def handle_event("switch_calendar_view", %{"view" => view}, socket) do
    {:noreply,
     socket
     |> assign(:calendar_view, view)
     |> push_event("update-calendar-view", %{view: view})}
  end

  @impl true
  def handle_event("switch_kanban_mode", %{"mode" => mode}, socket) do
    {:noreply, assign(socket, :kanban_mode, mode)}
  end

  @impl true
  def handle_event("apply_filters", %{"filters" => raw_filters}, socket) do
    new_filters = Map.merge(socket.assigns.filters, raw_filters)
    filter_opts = parse_filters(new_filters)

    orders_for_calendar = load_orders_for_calendar(socket, filter_opts)
    streamed_orders = load_streamed_orders(socket, filter_opts)
    calendar_events = create_calendar_events(orders_for_calendar)

    {:noreply,
     socket
     |> assign(:filters, new_filters)
     |> assign(:orders, orders_for_calendar)
     |> assign(:calendar_events, calendar_events)
     |> stream(:orders, streamed_orders, reset: true)}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    order = Orders.get_order_by_id!(id)

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
    calendar_events = create_calendar_events(orders_for_calendar)

    {:noreply,
     socket
     |> assign(:filters, new_filters)
     |> assign(:orders, orders_for_calendar)
     |> assign(:calendar_events, calendar_events)
     |> stream(:orders, streamed_orders, reset: true)
     |> push_event("update-calendar", %{events: calendar_events})}
  end

  @impl true
  def handle_info({MicrocraftWeb.OrderLive.FormComponent, {:saved, order}}, socket) do
    order = Ash.load!(order, [:items, :total_cost, customer: [:full_name]])
    orders = [order | socket.assigns.orders || []]
    calendar_events = create_calendar_events(orders)

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

    socket
    |> assign(:products, products)
    |> assign(:customers, customers)
    |> assign(:orders, orders_for_calendar)
    |> stream(:orders, streamed_orders)
  end

  defp assign_initial_view_state(socket) do
    socket
    |> assign(:view_mode, "table")
    |> assign(:calendar_view, "dayGridMonth")
    |> assign(:calendar_events, [])
    |> assign(:selected_order_reference, nil)
    |> assign(:kanban_mode, "order")
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

  # Group orders by their status for kanban view
  defp group_orders_by_status(orders) do
    all_statuses = [
      "unconfirmed",
      "confirmed",
      "in_process",
      "ready",
      "delivered",
      "completed",
      "cancelled"
    ]

    # First group orders by status
    grouped_orders =
      Enum.group_by(orders, fn order ->
        order_status = if is_atom(order.status), do: to_string(order.status), else: order.status
        order_status
      end)

    # Make sure all statuses exist in the result, even if there are no orders
    Enum.reduce(all_statuses, %{}, fn status, acc ->
      Map.put(acc, status, Map.get(grouped_orders, status, []))
    end)
  end

  # Group orders by products for kanban view
  defp group_orders_by_product(orders) do
    # First collect all unique product names
    product_names =
      orders
      |> Enum.flat_map(fn order ->
        if order.items, do: Enum.map(order.items, & &1.product.name), else: []
      end)
      |> Enum.uniq()
      |> Enum.sort()

    # Then group orders with their items by product
    Enum.reduce(product_names, %{}, fn product_name, acc ->
      # Find all orders that contain this product
      orders_with_product =
        orders
        |> Enum.filter(fn order ->
          order.items && Enum.any?(order.items, &(&1.product.name == product_name))
        end)
        |> Enum.map(fn order ->
          # Get just the items for this product
          items = Enum.filter(order.items, &(&1.product.name == product_name))
          {order, items}
        end)

      Map.put(acc, product_name, orders_with_product)
    end)
  end

  # Return appropriate CSS classes for status columns
  defp status_color_class("unconfirmed"), do: "bg-orange-100"
  defp status_color_class("confirmed"), do: "bg-blue-100"
  defp status_color_class("in_process"), do: "bg-purple-100"
  defp status_color_class("ready"), do: "bg-green-100"
  defp status_color_class("delivered"), do: "bg-sky-100"
  defp status_color_class("completed"), do: "bg-teal-100"
  defp status_color_class("cancelled"), do: "bg-red-100"
  defp status_color_class(_), do: "bg-gray-100"

  defp create_calendar_events(orders) do
    Enum.map(orders, fn order ->
      %{
        id: order.reference,
        title: "#{order.customer.full_name} - #{format_reference(order.reference)}",
        start: DateTime.to_iso8601(order.delivery_date),
        end:
          order.delivery_date
          |> DateTime.add(@calendar_event_duration, :second)
          |> DateTime.to_iso8601(),
        color: get_status_color_hex(order.status),
        textColor: "#000",
        url: nil,
        # Additional separated information for further customization
        extendedProps: %{
          customer: %{
            name: order.customer.full_name,
            reference: order.customer.reference
          },
          order: %{
            reference: order.reference,
            status: order.status,
            payment_status: order.payment_status,
            total_cost: order.total_cost
          }
        }
      }
    end)
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

  defp get_selected_order(orders, reference) when is_binary(reference) do
    Enum.find(orders, fn order -> order.reference == reference end)
  end

  defp get_selected_order(_orders, _reference), do: nil

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

  # Status color mapping for calendar events
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
