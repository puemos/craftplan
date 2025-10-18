defmodule CraftplanWeb.PurchasingLive.Suppliers do
  @moduledoc false
  use CraftplanWeb, :live_view

  alias Craftplan.Inventory

  @impl true
  def render(assigns) do
    assigns =
      assigns
      |> assign_new(:nav_sub_links, fn -> [] end)
      |> assign_new(:breadcrumbs, fn -> [] end)

    ~H"""
    <div class="mt-4">
      <.table
        id="suppliers"
        rows={@suppliers}
        row_click={fn sup -> JS.patch(~p"/manage/purchasing/suppliers/#{sup.id}/edit") end}
      >
        <:col :let={s} label="Name">{s.name}</:col>
        <:col :let={s} label="Contact">{s.contact_name}</:col>
        <:col :let={s} label="Email">{s.contact_email}</:col>
        <:col :let={s} label="Phone">{s.contact_phone}</:col>
        <:action :let={s}>
          <.link patch={~p"/manage/purchasing/suppliers/#{s.id}/edit"}>
            <.button size={:sm} variant={:outline}>Edit</.button>
          </.link>
        </:action>
      </.table>
    </div>

    <.modal
      :if={@live_action in [:new, :edit]}
      id="supplier-modal"
      show
      title={if @live_action == :new, do: "New Supplier", else: "Edit Supplier"}
      on_cancel={JS.patch(~p"/manage/purchasing/suppliers")}
    >
      <.live_component
        module={CraftplanWeb.PurchasingLive.SupplierFormComponent}
        id={(@supplier && @supplier.id) || :new}
        current_user={@current_user}
        supplier={@supplier}
        patch={~p"/manage/purchasing/suppliers"}
      />
    </.modal>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    suppliers = Inventory.list_suppliers!(actor: socket.assigns[:current_user])

    {:ok,
     socket
     |> assign(suppliers: suppliers, supplier: nil, purchasing_tab: :suppliers)
     |> assign(:nav_sub_links, purchasing_sub_links(:suppliers))
     |> assign(:breadcrumbs, suppliers_breadcrumbs(%{live_action: :index}))}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    socket = assign(socket, :page_title, "Suppliers")

    socket =
      case socket.assigns.live_action do
        :edit ->
          sup = Inventory.get_supplier_by_id!(params["id"], actor: socket.assigns.current_user)
          assign(socket, :supplier, sup)

        :new ->
          assign(socket, :supplier, nil)

        _ ->
          assign(socket, :supplier, nil)
      end

    {:noreply, assign(socket, :breadcrumbs, suppliers_breadcrumbs(socket.assigns))}
  end

  @impl true
  def handle_info({:supplier_saved, _sup}, socket) do
    {:noreply,
     socket
     |> assign(:suppliers, Inventory.list_suppliers!(actor: socket.assigns.current_user))
     |> put_flash(:info, "Supplier saved")
     |> push_event("close-modal", %{id: "supplier-modal"})}
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

  defp suppliers_breadcrumbs(%{live_action: :index}) do
    [
      %{label: "Purchasing", path: ~p"/manage/purchasing", current?: false},
      %{label: "Suppliers", path: ~p"/manage/purchasing/suppliers", current?: true}
    ]
  end

  defp suppliers_breadcrumbs(%{live_action: :new}) do
    [
      %{label: "Purchasing", path: ~p"/manage/purchasing", current?: false},
      %{label: "Suppliers", path: ~p"/manage/purchasing/suppliers", current?: false},
      %{label: "New Supplier", path: ~p"/manage/purchasing/suppliers/new", current?: true}
    ]
  end

  defp suppliers_breadcrumbs(%{live_action: :edit, supplier: %{} = supplier}) do
    [
      %{label: "Purchasing", path: ~p"/manage/purchasing", current?: false},
      %{label: "Suppliers", path: ~p"/manage/purchasing/suppliers", current?: false},
      %{
        label: supplier.name,
        path: ~p"/manage/purchasing/suppliers/#{supplier.id}/edit",
        current?: true
      }
    ]
  end

  defp suppliers_breadcrumbs(%{live_action: :edit}), do: suppliers_breadcrumbs(%{live_action: :new})

  defp suppliers_breadcrumbs(_), do: suppliers_breadcrumbs(%{live_action: :index})
end
