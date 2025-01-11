defmodule CraftScaleWeb.InventoryLive.Show do
  @moduledoc false
  use CraftScaleWeb, :live_view

  alias CraftScale.Inventory

  @impl true
  def render(assigns) do
    ~H"""
    <.header>
      <.breadcrumb>
        <:crumb label="All Materials" path={~p"/manage/inventory"} current?={false} />
        <:crumb label={@material.name} path={~p"/manage/inventory/#{@material.id}"} current?={true} />
      </.breadcrumb>

      <:actions>
        <.link patch={~p"/manage/inventory/#{@material.id}/adjust"} phx-click={JS.push_focus()}>
          <.button>Adjust Stock</.button>
        </.link>
        <.link patch={~p"/manage/inventory/#{@material.id}/edit"} phx-click={JS.push_focus()}>
          <.button>Edit</.button>
        </.link>
      </:actions>
    </.header>

    <.tabs id="material-tabs">
      <:tab
        label="Details"
        path={~p"/manage/inventory/#{@material.id}?page=details"}
        selected?={@page == "details"}
      >
        <.list>
          <:item title="Name">{@material.name}</:item>
          <:item title="SKU">
            <.kbd>
              {@material.sku}
            </.kbd>
          </:item>
          <:item title="Price">
            {format_money(@settings.currency, @material.price)}
          </:item>
          <:item title="Allergens">
            <div class="flex-inline items-center space-x-1">
              <.badge :for={allergen <- Enum.map(@material.allergens, & &1.name)} text={allergen} />
              <span :if={Enum.empty?(@material.allergens)}>None</span>
            </div>
          </:item>
          <:item title="Current Stock">
            {format_amount(@material.unit, @material.current_stock)}
          </:item>
          <:item title="Minimum Stock">
            {format_amount(@material.unit, @material.minimum_stock)}
          </:item>
          <:item title="Maximum Stock">
            {format_amount(@material.unit, @material.maximum_stock)}
          </:item>
        </.list>
      </:tab>

      <:tab
        label="Allergens"
        path={~p"/manage/inventory/#{@material.id}?page=allergens"}
        selected?={@page == "allergens"}
      >
        <.live_component
          module={CraftScaleWeb.InventoryLive.FormComponentAllergens}
          id="material-allergens-form"
          material={@material}
          current_user={@current_user}
          settings={@settings}
          patch={~p"/manage/inventory/#{@material.id}?page=allergens"}
          allergens={@allergens_available}
        />
      </:tab>

      <:tab
        label="Stock"
        path={~p"/manage/inventory/#{@material.id}?page=stock"}
        selected?={@page == "stock"}
      >
        <div class="-mt-11">
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
              {format_amount(@material.unit, entry.quantity)}
            </:col>
            <:col :let={entry} label="Reason">{entry.reason}</:col>
          </.table>
        </div>
      </:tab>
    </.tabs>

    <.modal
      :if={@live_action == :edit}
      id="material-modal"
      show
      on_cancel={JS.patch(~p"/manage/inventory/#{@material.id}")}
    >
      <.live_component
        module={CraftScaleWeb.InventoryLive.FormComponentMaterial}
        id={@material.id}
        title={@page_title}
        action={@live_action}
        current_user={@current_user}
        material={@material}
        settings={@settings}
        patch={~p"/manage/inventory/#{@material.id}?page=details"}
      />
    </.modal>
    <.modal
      :if={@live_action == :adjust}
      id="material-movement-modal"
      show
      on_cancel={JS.patch(~p"/manage/inventory/#{@material.id}")}
    >
      <.live_component
        module={CraftScaleWeb.InventoryLive.FormComponentMovement}
        id={@material.id}
        material={@material}
        current_user={@current_user}
        settings={@settings}
        patch={~p"/manage/inventory/#{@material.id}?page=stock"}
      />
    </.modal>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page, "details")
     |> assign(:allergens_available, list_all_allergens())}
  end

  @impl true
  def handle_params(%{"id" => id} = params, _, socket) do
    material =
      Inventory.get_material_by_id!(id,
        actor: socket.assigns[:current_user],
        load: [:current_stock, :movements, :allergens, :material_allergens]
      )

    page = Map.get(params, "page", "details")

    {:noreply,
     socket
     |> assign(:page_title, page_title(socket.assigns.live_action))
     |> assign(:material, material)
     |> assign(:page, page)}
  end

  defp list_all_allergens do
    CraftScale.Inventory.list_allergens!()
  end

  defp page_title(:show), do: "Show Material"
  defp page_title(:adjust), do: "Adjust Material"
  defp page_title(:edit), do: "Edit Material"
end
