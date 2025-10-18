defmodule CraftplanWeb.PurchasingLive.Index do
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
        <:crumb label="Purchase Orders" path={~p"/manage/purchasing"} current?={true} />
      </.breadcrumb>
      <:actions>
        <.link :if={@live_action == :index} patch={~p"/manage/purchasing/new"}>
          <.button variant={:primary}>New Purchase Order</.button>
        </.link>
        <.link navigate={~p"/manage/purchasing/suppliers"}>
          <.button variant={:outline}>Suppliers</.button>
        </.link>
      </:actions>
    </.header>

    <div class="mt-4">
      <.table id="purchase-orders" rows={@purchase_orders}>
        <:col :let={po} label="Reference">
          <.link navigate={~p"/manage/purchasing/#{po.reference}"}>
            <.kbd>{po.reference}</.kbd>
          </.link>
        </:col>
        <:col :let={po} label="Supplier">{po.supplier.name}</:col>
        <:col :let={po} label="Status">{po.status}</:col>
        <:col :let={po} label="Ordered">{format_time(po.ordered_at, @time_zone)}</:col>
        <:col :let={po} label="Received">{format_time(po.received_at, @time_zone)}</:col>

        <:action :let={po}>
          <.link patch={~p"/manage/purchasing/#{po.reference}/add_item"}>
            <.button size={:sm} variant={:outline}>Add Item</.button>
          </.link>
        </:action>
        <:action :let={po}>
          <.link :if={po.status != :received} phx-click={JS.push("receive", value: %{id: po.id})}>
            <.button size={:sm} variant={:primary}>Mark Received</.button>
          </.link>
        </:action>
      </.table>
    </div>

    <.modal
      :if={@live_action == :new}
      id="po-new-modal"
      show
      title="New Purchase Order"
      on_cancel={JS.patch(~p"/manage/purchasing")}
    >
      <.live_component
        module={CraftplanWeb.PurchasingLive.PurchaseOrderFormComponent}
        id="po-form"
        current_user={@current_user}
        suppliers={@suppliers}
        purchase_order={nil}
        patch={~p"/manage/purchasing"}
      />
    </.modal>

    <.modal
      :if={@live_action == :add_item}
      id="po-item-modal"
      show
      title={"Add Item to #{if @selected_po, do: @selected_po.reference, else: "PO"}"}
      on_cancel={JS.patch(~p"/manage/purchasing")}
    >
      <.live_component
        module={CraftplanWeb.PurchasingLive.PurchaseOrderItemFormComponent}
        id="po-item-form"
        current_user={@current_user}
        materials={@materials}
        po_id={@selected_po && @selected_po.id}
        purchase_order_item={nil}
        patch={~p"/manage/purchasing"}
      />
    </.modal>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    suppliers = Inventory.list_suppliers!(actor: socket.assigns[:current_user])
    materials = Inventory.list_materials!(actor: socket.assigns[:current_user])
    pos = load_purchase_orders(socket)

    {:ok,
     socket
     |> assign(
       suppliers: suppliers,
       materials: materials,
       purchase_orders: pos,
       selected_po: nil,
       purchasing_tab: :purchase_orders
     )
     |> assign(:nav_sub_links, purchasing_sub_links(:purchase_orders))}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    socket = assign(socket, :page_title, "Purchase Orders")

    socket =
      case socket.assigns.live_action do
        :add_item ->
          po =
            Inventory.get_purchase_order_by_reference!(params["po_ref"],
              load: [:supplier],
              actor: socket.assigns.current_user
            )

          assign(socket, :selected_po, po)

        _ ->
          assign(socket, :selected_po, nil)
      end

    {:noreply, socket}
  end

  @impl true
  def handle_event("receive", %{"id" => id}, socket) do
    _ = Receiving.receive_po(id, actor: socket.assigns.current_user)
    {:noreply, assign(socket, :purchase_orders, load_purchase_orders(socket))}
  end

  @impl true
  def handle_info({:po_saved, _po}, socket) do
    {:noreply,
     socket
     |> assign(:purchase_orders, load_purchase_orders(socket))
     |> put_flash(:info, "Purchase order created")
     |> push_event("close-modal", %{id: "po-new-modal"})}
  end

  defp purchasing_sub_links(active) do
    [
      %{
        label: "Purchase Orders",
        navigate: ~p"/manage/purchasing",
        active: active == :purchase_orders
      },
      %{
        label: "Suppliers",
        navigate: ~p"/manage/purchasing/suppliers",
        active: active == :suppliers
      }
    ]
  end

  @impl true
  def handle_info({:po_item_saved, _item}, socket) do
    {:noreply,
     socket
     |> put_flash(:info, "Item added to PO")
     |> push_event("close-modal", %{id: "po-item-modal"})}
  end

  defp load_purchase_orders(socket) do
    Inventory.list_purchase_orders!(actor: socket.assigns[:current_user], load: [:supplier])
  end
end
