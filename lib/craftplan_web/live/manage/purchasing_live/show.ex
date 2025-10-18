defmodule CraftplanWeb.PurchasingLive.Show do
  @moduledoc false
  use CraftplanWeb, :live_view

  alias Craftplan.Inventory
  alias Craftplan.Inventory.Receiving

  @impl true
  def render(assigns) do
    ~H"""
    <.header>
      <.breadcrumb>
        <:crumb label="Purchasing" path={~p"/manage/purchasing"} current?={false} />
        <:crumb label={@po.reference} path={~p"/manage/purchasing/#{@po.reference}"} current?={true} />
      </.breadcrumb>
      <:actions>
        <.link patch={~p"/manage/purchasing/#{@po.reference}/add_item"}>
          <.button variant={:outline}>Add Item</.button>
        </.link>
        <.link :if={@po.status != :received} phx-click={JS.push("receive", value: %{id: @po.id})}>
          <.button>Mark Received</.button>
        </.link>
      </:actions>
    </.header>

    <div class="mt-2">
      <.tabs_nav>
        <:tab>
          <.tab_link
            label="Overview"
            path={~p"/manage/purchasing/#{@po.reference}"}
            selected?={@live_action == :show}
          />
        </:tab>
        <:tab>
          <.tab_link
            label="Items"
            path={~p"/manage/purchasing/#{@po.reference}/items"}
            selected?={@live_action in [:items, :add_item]}
          />
        </:tab>
      </.tabs_nav>
    </div>

    <div class="mt-4 space-y-4">
      <%= if @live_action == :show do %>
        <.list>
          <:item title="Reference">
            <.kbd>{@po.reference}</.kbd>
          </:item>
          <:item title="Supplier">{@po.supplier.name}</:item>
          <:item title="Status">{@po.status}</:item>
          <:item title="Ordered At">{format_time(@po.ordered_at, @time_zone)}</:item>
          <:item title="Received At">{format_time(@po.received_at, @time_zone)}</:item>
        </.list>
      <% else %>
        <div>
          <.table id="po-items" rows={@po.items}>
            <:col :let={i} label="Material">{i.material.name}</:col>
            <:col :let={i} label="Quantity">{format_amount(i.material.unit, i.quantity)}</:col>
            <:col :let={i} label="Unit Price">
              {format_money(@settings.currency, i.unit_price || Decimal.new(0))}
            </:col>
          </.table>
        </div>
      <% end %>
    </div>

    <.modal
      :if={@live_action == :add_item}
      id="po-item-modal"
      show
      title={"Add Item to #{@po.reference}"}
      on_cancel={
        JS.patch(
          if @live_action in [:items, :add_item],
            do: ~p"/manage/purchasing/#{@po.reference}/items",
            else: ~p"/manage/purchasing/#{@po.reference}"
        )
      }
    >
      <.live_component
        module={CraftplanWeb.PurchasingLive.PurchaseOrderItemFormComponent}
        id="po-item-form"
        current_user={@current_user}
        materials={@materials}
        po_id={@po.id}
        purchase_order_item={nil}
        patch={
          if @live_action in [:items, :add_item],
            do: ~p"/manage/purchasing/#{@po.reference}/items",
            else: ~p"/manage/purchasing/#{@po.reference}"
        }
      />
    </.modal>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    materials = Inventory.list_materials!(actor: socket.assigns[:current_user])
    {:ok, assign(socket, materials: materials, purchasing_tab: :purchase_orders)}
  end

  @impl true
  def handle_params(%{"po_ref" => ref}, _uri, socket) do
    opts = [actor: socket.assigns[:current_user], load: [:supplier, items: [material: [:unit]]]]

    case Inventory.get_purchase_order_by_reference(ref, opts) do
      {:ok, nil} ->
        {:noreply,
         socket
         |> put_flash(:error, "Purchase order not found")
         |> push_navigate(to: ~p"/manage/purchasing")}

      {:ok, po} ->
        {:noreply, assign(socket, po: po)}

      {:error, _} ->
        {:noreply,
         socket
         |> put_flash(:error, "Unable to load purchase order")
         |> push_navigate(to: ~p"/manage/purchasing")}
    end
  end

  @impl true
  def handle_event("receive", %{"id" => id}, socket) do
    _ = Receiving.receive_po(id, actor: socket.assigns.current_user)
    {:noreply, push_navigate(socket, to: ~p"/manage/purchasing/#{socket.assigns.po.reference}")}
  end

  @impl true
  def handle_info({:po_item_saved, _item}, socket) do
    po =
      Inventory.get_purchase_order_by_reference!(socket.assigns.po.reference,
        actor: socket.assigns[:current_user],
        load: [:supplier, items: [material: [:unit]]]
      )

    {:noreply,
     socket
     |> assign(:po, po)
     |> put_flash(:info, "Item added to PO")
     |> push_event("close-modal", %{id: "po-item-modal"})}
  end
end
