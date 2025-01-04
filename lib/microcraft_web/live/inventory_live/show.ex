defmodule MicrocraftWeb.InventoryLive.Show do
  @moduledoc false
  use MicrocraftWeb, :live_view

  alias Microcraft.Inventory

  @impl true
  def render(assigns) do
    ~H"""
    <.header>
      <.breadcrumb>
        <:crumb label="All Materials" path={~p"/backoffice/inventory"} current?={false} />
        <:crumb
          label={@material.name}
          path={~p"/backoffice/inventory/#{@material.id}"}
          current?={true}
        />
      </.breadcrumb>

      <:actions>
        <.link patch={~p"/backoffice/inventory/#{@material.id}/adjust"} phx-click={JS.push_focus()}>
          <.button>Adjust</.button>
        </.link>
        <.link patch={~p"/backoffice/inventory/#{@material.id}/edit"} phx-click={JS.push_focus()}>
          <.button>Edit</.button>
        </.link>
      </:actions>
    </.header>

    <.tabs id="material-tabs">
      <:tab
        label="Details"
        path={~p"/backoffice/inventory/#{@material.id}?page=details"}
        selected?={@page == "details"}
      >
        <.list>
          <:item title="Name">{@material.name}</:item>
          <:item title="SKU">{@material.sku}</:item>
          <:item title="Price">
            {format_money(@settings.currency, @material.price)}
          </:item>
          <:item title="Current Stock">
            {@material.current_stock || 0} {@material.unit}
          </:item>
          <:item title="Minimum Stock">
            {@material.minimum_stock} {@material.unit}
          </:item>
          <:item title="Maximum Stock">
            {@material.maximum_stock} {@material.unit}
          </:item>
        </.list>
      </:tab>

      <:tab
        label="Log"
        path={~p"/backoffice/inventory/#{@material.id}?page=log"}
        selected?={@page == "log"}
      >
        <.table id="inventory_movements" rows={@material.movements}>
          <:empty>
            <div class="block py-4 pr-6">
              <span class={["relative"]}>
                No movements found
              </span>
            </div>
          </:empty>

          <:col :let={entry} label="Date">
            {Calendar.strftime(entry.inserted_at, "%Y-%m-%d %H:%M")}
          </:col>

          <:col :let={entry} label="Quantity">
            {entry.quantity} {@material.unit}
          </:col>
          <:col :let={entry} label="Reason">{entry.reason}</:col>
        </.table>
      </:tab>
    </.tabs>

    <.modal
      :if={@live_action == :edit}
      id="material-modal"
      show
      on_cancel={JS.patch(~p"/backoffice/inventory/#{@material.id}")}
    >
      <.live_component
        module={MicrocraftWeb.InventoryLive.FormComponentMaterial}
        id={@material.id}
        title={@page_title}
        action={@live_action}
        current_user={@current_user}
        material={@material}
        settings={@settings}
        patch={~p"/backoffice/inventory/#{@material.id}?page=details"}
      />
    </.modal>
    <.modal
      :if={@live_action == :adjust}
      id="material-movement-modal"
      show
      on_cancel={JS.patch(~p"/backoffice/inventory/#{@material.id}")}
    >
      <.live_component
        module={MicrocraftWeb.InventoryLive.FormComponentMovement}
        id={@material.id}
        material={@material}
        current_user={@current_user}
        settings={@settings}
        patch={~p"/backoffice/inventory/#{@material.id}?page=log"}
      />
    </.modal>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def handle_params(%{"id" => id} = params, _, socket) do
    material =
      Inventory.get_material_by_id!(id,
        actor: socket.assigns[:current_user],
        load: [:current_stock, :movements]
      )

    page = Map.get(params, "page", "details")

    {:noreply,
     socket
     |> assign(:page_title, page_title(socket.assigns.live_action))
     |> assign(:material, material)
     |> assign(:page, page)}
  end

  defp page_title(:show), do: "Show Material"
  defp page_title(:adjust), do: "Adjust Material"
  defp page_title(:edit), do: "Edit Material"
end
