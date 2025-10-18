defmodule CraftplanWeb.OrderLive.Show do
  @moduledoc false
  use CraftplanWeb, :live_view

  alias Craftplan.Catalog
  alias Craftplan.Catalog.Product.Photo
  alias Craftplan.CRM
  alias Craftplan.Orders

  @default_order_load [
    :total_cost,
    items: [:cost, :status, :consumed_at, product: [:name, :sku]],
    customer: [:full_name, shipping_address: [:full_address]]
  ]

  @impl true
  def render(assigns) do
    assigns =
      assign_new(assigns, :breadcrumbs, fn -> [] end)

    ~H"""
    <.header>
      {@order.reference}
      <:actions>
        <.link patch={~p"/manage/orders/#{@order.reference}/edit"} phx-click={JS.push_focus()}>
          <.button variant={:primary}>Edit order</.button>
        </.link>
        <.link navigate={~p"/manage/orders/#{@order.reference}/invoice"}>
          <.button variant={:outline}>View Invoice</.button>
        </.link>
      </:actions>
    </.header>

    <.sub_nav links={@tabs_links} />

    <div class="mt-4 space-y-6">
      <div :if={@live_action in [:details, :show, :edit]}>
        <.list>
          <:item title="Reference">
            <.kbd>
              {format_reference(@order.reference)}
            </.kbd>
          </:item>

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
            <.link
              class="hover:text-blue-800 hover:underline"
              navigate={~p"/manage/customers/#{@order.customer.reference}"}
            >
              {@order.customer.full_name}
            </.link>
          </:item>
          <:item title="Shipping Address">
            {if @order.customer.shipping_address do
              @order.customer.shipping_address.full_address
            else
              "N/A"
            end}
          </:item>

          <:item title="Total">
            {format_money(@settings.currency, @order.total_cost)}
          </:item>

          <:item title="Delivery Date">
            {format_time(@order.delivery_date, @time_zone)}
          </:item>

          <:item title="Created At">
            {format_time(@order.inserted_at, @time_zone)}
          </:item>
        </.list>
      </div>

      <div :if={@live_action == :items}>
        <.table id="order-items" rows={@order.items}>
          <:col :let={item} label="Product">
            <.link
              class="hover:text-blue-800 hover:underline"
              navigate={~p"/manage/products/#{item.product.sku}"}
            >
              <div class="flex items-center space-x-2">
                <img
                  :if={item.product.featured_photo != nil}
                  src={Photo.url({item.product.featured_photo, item.product}, :thumb, signed: true)}
                  alt={item.product.name}
                  class="h-5 w-5"
                />
                <span>
                  {item.product.name}
                </span>
              </div>
            </.link>
          </:col>
          <:col :let={item} label="Quantity">{item.quantity}</:col>
          <:col :let={item} label="Unit Price">
            {format_money(@settings.currency, item.product.price)}
          </:col>
          <:col :let={item} label="Total">
            {format_money(@settings.currency, item.cost)}
          </:col>
          <:col :let={item} label="Status">
            <form phx-change="update_item_status">
              <input type="hidden" name="item_id" value={item.id} />
              <.input
                name="status"
                type="badge-select"
                value={item.status}
                options={[
                  {"To Do", "todo"},
                  {"In Progress", "in_progress"},
                  {"Completed", "done"}
                ]}
                badge_colors={[
                  {:todo, "#{order_item_status_bg(:todo)} #{order_item_status_color(:todo)}"},
                  {:in_progress,
                   "#{order_item_status_bg(:in_progress)} #{order_item_status_color(:in_progress)}"},
                  {:done, "#{order_item_status_bg(:done)} #{order_item_status_color(:done)}"}
                ]}
              />
            </form>
            <span
              :if={item.status == :done && not is_nil(item.consumed_at)}
              class="ml-2 text-xs text-stone-500"
            >
              Consumed
            </span>
          </:col>
        </.table>
      </div>
    </div>

    <.modal
      :if={@pending_consumption_item_id}
      id="consume-confirm-modal"
      show
      title="Confirm Materials Consumption"
      on_cancel={JS.push("cancel_consume")}
    >
      <p class="mb-3 text-sm text-stone-700">
        Completing this item will consume materials per the product recipe. Review the quantities and confirm.
      </p>
      <.table id="order-consumption-recap" rows={@pending_consumption_recap}>
        <:col :let={row} label="Material">{row.material.name}</:col>
        <:col :let={row} label="Required">{format_amount(row.material.unit, row.required)}</:col>
        <:col :let={row} label="Current Stock">
          {format_amount(row.material.unit, row.current_stock || Decimal.new(0))}
        </:col>
      </.table>
      <footer>
        <.button variant={:outline} phx-click="cancel_consume">Close</.button>
        <.button variant={:primary} phx-click="confirm_consume">Consume Now</.button>
      </footer>
    </.modal>

    <.modal
      :if={@live_action == :edit}
      id="order-modal"
      show
      title={@page_title}
      on_cancel={JS.patch(~p"/manage/orders/#{@order.reference}")}
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
        patch={~p"/manage/orders/#{@order.reference}"}
      />
    </.modal>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    products =
      Catalog.list_products!(actor: socket.assigns[:current_user])

    customers =
      CRM.list_customers!(actor: socket.assigns[:current_user], load: [:full_name])

    {:ok,
     assign(socket,
       products: products,
       customers: customers,
       pending_consumption_item_id: nil,
       pending_consumption_recap: []
     )}
  end

  @impl true
  def handle_params(%{"reference" => reference}, _, socket) do
    order =
      Orders.get_order_by_reference!(reference,
        load: @default_order_load,
        actor: socket.assigns[:current_user]
      )

    live_action = socket.assigns.live_action

    tabs_links = [
      %{
        label: "Details",
        navigate: ~p"/manage/orders/#{order.reference}/details",
        active: live_action in [:details, :show]
      },
      %{
        label: "Items",
        navigate: ~p"/manage/orders/#{order.reference}/items",
        active: live_action == :items
      }
    ]

    socket =
      socket
      |> assign(:page_title, page_title(live_action))
      |> assign(:order, order)
      |> assign(:tabs_links, tabs_links)
      |> assign(:breadcrumbs, order_breadcrumbs(order, live_action))

    {:noreply, socket}
  end

  @impl true
  def handle_event("update_item_status", %{"item_id" => id, "status" => status}, socket) do
    order_item = Orders.get_order_item_by_id!(id, actor: socket.assigns.current_user)

    case Orders.update_item(order_item, %{status: String.to_atom(status)}, actor: socket.assigns.current_user) do
      {:ok, updated_item} ->
        order =
          Orders.get_order_by_id!(order_item.order_id,
            load: @default_order_load,
            actor: socket.assigns[:current_user]
          )

        socket =
          socket
          |> assign(:order, order)
          |> put_flash(:info, "Item status updated")

        socket =
          if String.to_atom(status) == :done do
            item =
              Orders.get_order_item_by_id!(updated_item.id,
                load: [
                  :quantity,
                  product: [recipe: [components: [material: [:name, :unit, :current_stock]]]]
                ],
                actor: socket.assigns[:current_user]
              )

            recap =
              case item.product.recipe do
                nil ->
                  []

                recipe ->
                  Enum.map(recipe.components, fn c ->
                    %{
                      material: c.material,
                      required: Decimal.mult(c.quantity, item.quantity),
                      current_stock: c.material.current_stock
                    }
                  end)
              end

            socket
            |> assign(:pending_consumption_item_id, updated_item.id)
            |> assign(:pending_consumption_recap, recap)
          else
            socket
          end

        {:noreply, socket}

      {:error, _} ->
        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("confirm_consume", _params, socket) do
    if socket.assigns.pending_consumption_item_id do
      _ =
        Craftplan.Orders.Consumption.consume_item(socket.assigns.pending_consumption_item_id,
          actor: socket.assigns.current_user
        )

      order =
        Orders.get_order_by_id!(socket.assigns.order.id,
          load: @default_order_load,
          actor: socket.assigns[:current_user]
        )

      {:noreply,
       socket
       |> assign(:order, order)
       |> assign(:pending_consumption_item_id, nil)
       |> assign(:pending_consumption_recap, [])
       |> put_flash(:info, "Materials consumed")}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("cancel_consume", _params, socket) do
    {:noreply,
     socket
     |> assign(:pending_consumption_item_id, nil)
     |> assign(:pending_consumption_recap, [])}
  end

  @impl true
  def handle_info({CraftplanWeb.OrderLive.FormComponentItems, {:saved, _}}, socket) do
    order =
      Orders.get_order_by_id!(socket.assigns.order.id,
        load: @default_order_load,
        actor: socket.assigns[:current_user]
      )

    {:noreply,
     socket
     |> put_flash(:info, "Order items updated successfully")
     |> assign(:order, order)
     |> push_event("close-modal", %{id: "order-item-modal"})}
  end

  @impl true
  def handle_info({CraftplanWeb.OrderLive.FormComponent, {:saved, _}}, socket) do
    order =
      Orders.get_order_by_id!(socket.assigns.order.id,
        load: @default_order_load,
        actor: socket.assigns[:current_user]
      )

    {:noreply,
     socket
     |> put_flash(:info, "Order updated successfully")
     |> assign(:order, order)}
  end

  defp page_title(:show), do: "Show Order"
  defp page_title(:edit), do: "Edit Order"
  defp page_title(:details), do: "Order Details"
  defp page_title(:items), do: "Order Items"

  defp order_breadcrumbs(order, live_action) do
    base = [
      %{label: "Orders", path: ~p"/manage/orders", current?: false},
      %{
        label: format_reference(order.reference),
        path: ~p"/manage/orders/#{order.reference}",
        current?: live_action in [:show, :details]
      }
    ]

    case live_action do
      :items ->
        base ++
          [
            %{
              label: "Items",
              path: ~p"/manage/orders/#{order.reference}/items",
              current?: true
            }
          ]

      _ ->
        List.update_at(base, 1, &Map.put(&1, :current?, true))
    end
  end
end
