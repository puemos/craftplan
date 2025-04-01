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
      </div>
    </form>

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
            {order.status, "#{order_status_color(order.status)} #{order_status_bg(order.status)}"}
          ]}
        />
      </:col>

      <:col :let={{_id, order}} label="Payment">
        <.badge text={"#{emoji_for_payment(order.payment_status)} #{order.payment_status}"} />
      </:col>
    </.table>

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
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    socket = assign(socket, :filters, @default_filters)

    filter_opts = parse_filters(@default_filters)

    orders =
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

    {:ok,
     socket
     |> assign(:products, products)
     |> assign(:customers, customers)
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
  def handle_event("apply_filters", %{"filters" => raw_filters}, socket) do
    new_filters = Map.merge(socket.assigns.filters, raw_filters)

    filter_opts = parse_filters(new_filters)

    orders =
      Orders.list_orders!(
        filter_opts,
        actor: socket.assigns[:current_user],
        stream?: true,
        load: [:items, :total_cost, customer: [:full_name]]
      )

    socket =
      socket
      |> assign(:filters, new_filters)
      |> stream(:orders, orders, reset: true)

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
  def handle_info({MicrocraftWeb.OrderLive.FormComponent, {:saved, order}}, socket) do
    order = Ash.load!(order, [:items, :total_cost, customer: [:full_name]])
    {:noreply, stream_insert(socket, :orders, order)}
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
end
