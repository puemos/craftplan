defmodule CraftplanWeb.OrderLive.Show do
  @moduledoc false
  use CraftplanWeb, :live_view

  import Ash.Expr

  alias Craftplan.Catalog
  alias Craftplan.Catalog.Product.Photo
  alias Craftplan.CRM
  alias Craftplan.Orders
  alias Craftplan.Orders.OrderItemBatchAllocation
  alias CraftplanWeb.Navigation

  require Ash.Query

  @default_order_load [
    :total_cost,
    items: [
      :cost,
      :status,
      :consumed_at,
      :batch_code,
      :planned_qty_sum,
      :completed_qty_sum,
      :material_cost,
      :labor_cost,
      :overhead_cost,
      :unit_cost,
      product: [:name, :sku]
    ],
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
      <.tabs_content :if={@live_action in [:details, :show, :edit]}>
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
      </.tabs_content>

      <.tabs_content :if={@live_action == :items}>
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
            <% planned = item.planned_qty_sum || Decimal.new(0) %>
            <% completed = item.completed_qty_sum || Decimal.new(0) %>
            <% status =
              cond do
                Decimal.compare(completed, item.quantity) != :lt -> :done
                Decimal.compare(completed, Decimal.new(0)) == :gt -> :in_progress
                true -> :todo
              end %>
            <.badge
              text={status}
              colors={[
                {:todo, "#{order_item_status_bg(:todo)} #{order_item_status_color(:todo)}"},
                {:in_progress,
                 "#{order_item_status_bg(:in_progress)} #{order_item_status_color(:in_progress)}"},
                {:done, "#{order_item_status_bg(:done)} #{order_item_status_color(:done)}"}
              ]}
            />
          </:col>
          <:col :let={item} label="Allocations">
            <div class="flex items-center gap-2 text-xs">
              <span class="inline-flex items-center rounded bg-stone-100 px-2 py-0.5">
                Planned: {item.planned_qty_sum || Decimal.new(0)}
              </span>
              <span class="inline-flex items-center rounded bg-stone-100 px-2 py-0.5">
                Completed: {item.completed_qty_sum || Decimal.new(0)}
              </span>
            </div>
          </:col>
          <:action :let={item}>
            <.button
              size={:sm}
              variant={:outline}
              phx-click="open_add_to_batch"
              phx-value-item_id={item.id}
            >
              Add to Batch…
            </.button>
          </:action>
          <:col :let={item} label="Batch">
            <%= if item.batch_code do %>
              <.link
                navigate={~p"/manage/production/batches/#{item.batch_code}"}
                class="text-xs text-blue-700 hover:underline"
              >
                {item.batch_code}
              </.link>
            <% else %>
              <span class="text-xs text-stone-600">-</span>
            <% end %>
          </:col>
          <:col :let={item} label="Unit Cost">
            {format_money(@settings.currency, item.unit_cost || Decimal.new(0))}
          </:col>
        </.table>
      </.tabs_content>
    </div>

    <.modal
      :if={@pending_consumption_item_id}
      id="consume-confirm-modal"
      show
      title="Confirm Materials Consumption"
      on_cancel={JS.push("cancel_consume")}
    >
      <p class="mb-3 text-sm text-stone-700">
        Completing this item will consume materials per the product's BOM. Review the quantities and confirm.
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

    <.modal
      :if={@add_to_batch_item}
      id="add-to-batch-modal"
      show
      title="Add Item to Batch"
      on_cancel={JS.push("cancel_add_to_batch")}
    >
      <.form id="add-to-batch-form" for={%{}} phx-submit="save_add_to_batch">
        <div class="space-y-3">
          <div class="text-sm text-stone-700">
            Product: <span class="font-medium">{@add_to_batch_item.product.name}</span>
          </div>
          <.input
            type="select"
            name="batch_id"
            label="Open Batch"
            options={for b <- @open_batches, do: {b.batch_code, b.id}}
            value={@selected_batch_id}
          />
          <.input
            type="number"
            name="planned_qty"
            label="Planned Quantity"
            min="0"
            step="any"
            value={@default_planned_qty}
          />
          <div class="flex items-center justify-end gap-2">
            <.button type="button" variant={:outline} phx-click="cancel_add_to_batch">Cancel</.button>
            <.button type="submit" variant={:primary}>Add</.button>
          </div>
        </div>
      </.form>
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
       add_to_batch_item: nil,
       open_batches: [],
       default_planned_qty: Decimal.new(0),
       selected_batch_id: nil,
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

    {:noreply, Navigation.assign(socket, :orders, order_trail(order, live_action))}
  end

  @impl true
  def handle_event("update_item_status", _params, socket), do: {:noreply, socket}

  @impl true
  def handle_event("confirm_consume", _params, socket), do: {:noreply, socket}

  @impl true
  def handle_event("cancel_consume", _params, socket), do: {:noreply, socket}

  @impl true
  def handle_event("open_add_to_batch", %{"item_id" => item_id}, socket) do
    actor = socket.assigns.current_user

    item =
      Orders.get_order_item_by_id!(item_id,
        actor: actor,
        load: [:quantity, :planned_qty_sum, product: [:name, :sku]]
      )

    open_batches =
      Craftplan.Orders.ProductionBatch
      |> Ash.Query.new()
      |> Ash.Query.filter(expr(product_id == ^item.product_id and status == :open))
      |> Ash.Query.sort(inserted_at: :desc)
      |> Ash.read!(actor: actor)

    remaining = Decimal.sub(item.quantity, item.planned_qty_sum || Decimal.new(0))

    selected =
      open_batches
      |> List.first()
      |> case do
        nil -> nil
        b -> b.id
      end

    {:noreply,
     socket
     |> assign(:add_to_batch_item, item)
     |> assign(:open_batches, open_batches)
     |> assign(:default_planned_qty, remaining)
     |> assign(:selected_batch_id, selected)}
  end

  @impl true
  def handle_event("save_add_to_batch", %{"batch_id" => batch_id, "planned_qty" => planned_qty}, socket) do
    actor = socket.assigns.current_user
    item = socket.assigns.add_to_batch_item
    qty = Decimal.new(planned_qty)

    existing =
      OrderItemBatchAllocation
      |> Ash.Query.new()
      |> Ash.Query.filter(expr(order_item_id == ^item.id and production_batch_id == ^batch_id))
      |> Ash.read_one(actor: actor)

    case existing do
      {:ok, %{} = alloc} ->
        _ =
          Ash.update!(
            alloc,
            %{planned_qty: Decimal.add(alloc.planned_qty || Decimal.new(0), qty)},
            action: :update,
            actor: actor
          )

        :ok

      _ ->
        _ =
          OrderItemBatchAllocation
          |> Ash.Changeset.for_create(:create, %{
            order_item_id: item.id,
            production_batch_id: batch_id,
            planned_qty: qty,
            completed_qty: Decimal.new(0)
          })
          |> Ash.create!(actor: actor)

        :ok
    end

    order =
      Orders.get_order_by_id!(socket.assigns.order.id,
        load: @default_order_load,
        actor: actor
      )

    {:noreply,
     socket
     |> assign(:order, order)
     |> assign(:add_to_batch_item, nil)
     |> assign(:open_batches, [])
     |> assign(:selected_batch_id, nil)
     |> put_flash(:info, "Allocation added")}
  rescue
    e ->
      {:noreply, put_flash(socket, :error, "Failed to add allocation: #{Exception.message(e)}")}
  end

  @impl true
  def handle_event("cancel_add_to_batch", _params, socket) do
    {:noreply,
     socket
     |> assign(:add_to_batch_item, nil)
     |> assign(:open_batches, [])
     |> assign(:selected_batch_id, nil)}
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

  defp order_trail(order, :items) do
    [
      Navigation.root(:orders),
      Navigation.resource(:order, order),
      Navigation.page(:orders, :order_items, order)
    ]
  end

  defp order_trail(order, _), do: [Navigation.root(:orders), Navigation.resource(:order, order)]
end
