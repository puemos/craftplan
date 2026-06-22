defmodule CraftplanWeb.InventoryLive.Show do
  @moduledoc false
  use CraftplanWeb, :live_view

  require Ash.Query

  alias Craftplan.Inventory
  alias Craftplan.Inventory.Movement
  alias CraftplanWeb.Navigation

  defp movements_query do
    Movement
    |> Ash.Query.sort(occurred_at: :desc)
    |> Ash.Query.load(:lot)
  end

  defp material_load_opts do
    [
      :current_stock,
      {:movements, movements_query()},
      :allergens,
      :material_allergens,
      :nutritional_facts,
      material_nutritional_facts: [:nutritional_fact]
    ]
  end

  @impl true
  def render(assigns) do
    assigns =
      assigns
      |> assign_new(:tabs_links, fn -> [] end)
      |> assign_new(:breadcrumbs, fn -> [] end)

    ~H"""
    <.header>
      {@material.name}
      <:actions>
        <.link patch={~p"/manage/inventory/#{@material.sku}/edit"} phx-click={JS.push_focus()}>
          <.button>Edit</.button>
        </.link>
        <.link patch={~p"/manage/inventory/#{@material.sku}/adjust"} phx-click={JS.push_focus()}>
          <.button variant={:primary}>Adjust Stock</.button>
        </.link>
      </:actions>
    </.header>

    <.sub_nav links={@tabs_links} />

    <div class="mt-4 space-y-6">
      <.tabs_content :if={@live_action in [:details, :show]}>
        <.list>
          <:item title="Name">{@material.name}</:item>
          <:item title="SKU">
            <.kbd>
              {@material.sku}
            </.kbd>
          </:item>
          <:item title="Price">
            {format_unit_price(@settings.currency, @material.price)} / {Craftplan.Types.Unit.abbreviation(@material.unit)}
          </:item>
          <:item title="Allergens">
            <div class="flex-inline items-center space-x-1">
              <.badge :for={allergen <- Enum.map(@material.allergens, & &1.name)} text={allergen} />
              <span :if={Enum.empty?(@material.allergens)}>None</span>
            </div>
          </:item>
          <:item title="Nutrition">
            <div class="flex-inline items-center space-x-1">
              <.badge
                :for={fact <- @material.material_nutritional_facts}
                text={"#{fact.nutritional_fact.name}: #{fact.amount} #{fact.unit}"}
              />
              <span :if={Enum.empty?(@material.material_nutritional_facts)}>None</span>
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

        <div :if={!Enum.empty?(@open_po_items)} class="mt-6">
          <div class="mb-2 text-base font-medium text-stone-900">Open Purchase Orders</div>
          <.table id="material-open-pos" rows={@open_po_items}>
            <:col :let={poi} label="Purchase Order">
              <.link navigate={~p"/manage/purchasing/#{poi.purchase_order.reference}"}>
                <.kbd>{poi.purchase_order.reference}</.kbd>
              </.link>
            </:col>
            <:col :let={poi} label="Supplier">
              <.link navigate={~p"/manage/purchasing/suppliers"} class="hover:underline">
                {poi.purchase_order.supplier.name}
              </.link>
            </:col>
            <:col :let={poi} label="Quantity">
              {format_amount(@material.unit, poi.quantity)}
            </:col>
            <:col :let={poi} label="Status">{poi.purchase_order.status}</:col>
          </.table>
        </div>
      </.tabs_content>

      <.tabs_content :if={@live_action == :allergens}>
        <.live_component
          module={CraftplanWeb.InventoryLive.FormComponentAllergens}
          id="material-allergens-form"
          material={@material}
          current_user={@current_user}
          settings={@settings}
          patch={~p"/manage/inventory/#{@material.sku}/allergens"}
          allergens={@allergens_available}
        />
      </.tabs_content>

      <.tabs_content :if={@live_action == :nutritional_facts}>
        <.live_component
          module={CraftplanWeb.InventoryLive.FormComponentNutritionalFacts}
          id="material-nutritional-facts-form"
          material={@material}
          current_user={@current_user}
          settings={@settings}
          patch={~p"/manage/inventory/#{@material.sku}/nutritional_facts"}
          nutritional_facts={@nutritional_facts_available}
        />
      </.tabs_content>

      <.tabs_content :if={@live_action == :stock}>
        <div>
          <.table id="inventory_movements" no_margin rows={@material.movements}>
            <:empty>
              <div class="block py-4 pr-6">
                <span class={["relative"]}>
                  No movements yet. Stock changes will appear here.
                </span>
              </div>
            </:empty>

            <:col :let={entry} label="Date">
              {format_time(entry.occurred_at || entry.inserted_at, @time_zone)}
            </:col>

            <:col :let={entry} label="Quantity">
              <span class={if Decimal.negative?(entry.quantity), do: "text-rose-700", else: "text-emerald-700"}>
                {format_amount(@material.unit, entry.quantity)}
              </span>
            </:col>

            <:col :let={entry} label="Lot">
              <.kbd :if={entry.lot && entry.lot.lot_code}>{entry.lot.lot_code}</.kbd>
              <span :if={!entry.lot} class="text-stone-400">—</span>
            </:col>

            <:col :let={entry} label="Reason">
              {render_reason(entry.reason)}
            </:col>
          </.table>
        </div>
      </.tabs_content>
    </div>

    <.modal
      :if={@live_action == :edit}
      id="material-modal"
      title={@page_title}
      show
      on_cancel={JS.patch(~p"/manage/inventory/#{@material.sku}")}
    >
      <.live_component
        module={CraftplanWeb.InventoryLive.FormComponentMaterial}
        id={@material.id}
        title={@page_title}
        action={@live_action}
        current_user={@current_user}
        material={@material}
        settings={@settings}
        patch={~p"/manage/inventory/#{@material.sku}/details"}
      />
    </.modal>
    <.modal
      :if={@live_action == :adjust}
      title={"Adjust Stock for #{@material.name}"}
      id="material-movement-modal"
      show
      on_cancel={JS.patch(~p"/manage/inventory/#{@material.sku}")}
    >
      <.live_component
        module={CraftplanWeb.InventoryLive.FormComponentMovement}
        id={@material.id}
        material={@material}
        current_user={@current_user}
        settings={@settings}
        patch={~p"/manage/inventory/#{@material.sku}/stock"}
      />
    </.modal>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(
       :allergens_available,
       Inventory.list_allergens!(actor: socket.assigns[:current_user])
     )
     |> assign(
       :nutritional_facts_available,
       Inventory.list_nutritional_facts!(actor: socket.assigns[:current_user])
     )}
  end

  @impl true
  def handle_params(%{"sku" => sku}, _, socket) do
    material =
      Inventory.get_material_by_sku!(sku,
        actor: socket.assigns[:current_user],
        load: material_load_opts()
      )

    open_po_items =
      Inventory.list_open_po_items_for_material!(
        %{material_id: material.id},
        actor: socket.assigns[:current_user]
      )

    live_action = socket.assigns.live_action

    tabs_links = [
      %{
        label: "Details",
        navigate: ~p"/manage/inventory/#{material.sku}/details",
        active: live_action in [:details, :show]
      },
      %{
        label: "Allergens",
        navigate: ~p"/manage/inventory/#{material.sku}/allergens",
        active: live_action == :allergens
      },
      %{
        label: "Nutrition",
        navigate: ~p"/manage/inventory/#{material.sku}/nutritional_facts",
        active: live_action == :nutritional_facts
      },
      %{
        label: "Stock",
        navigate: ~p"/manage/inventory/#{material.sku}/stock",
        active: live_action == :stock
      }
    ]

    socket =
      socket
      |> assign(:page_title, page_title(live_action))
      |> assign(:material, material)
      |> assign(:open_po_items, open_po_items)
      |> assign(:tabs_links, tabs_links)

    {:noreply, Navigation.assign(socket, :inventory, material_trail(material, live_action))}
  end

  # helper functions removed; calls now pass actor explicitly in mount

  @impl true
  def handle_info({:saved_nutritional_facts, material_id}, socket) do
    material =
      Inventory.get_material_by_id!(material_id,
        actor: socket.assigns[:current_user],
        load: material_load_opts()
      )

    {:noreply, assign(socket, :material, material)}
  end

  @impl true
  def handle_info({:saved_allergens, material_id}, socket) do
    material =
      Inventory.get_material_by_id!(material_id,
        actor: socket.assigns[:current_user],
        load: material_load_opts()
      )

    {:noreply, assign(socket, :material, material)}
  end

  @impl true
  def handle_info({:saved, %Inventory.Movement{material_id: material_id}}, socket) do
    material =
      Inventory.get_material_by_id!(material_id,
        actor: socket.assigns[:current_user],
        load: material_load_opts()
      )

    {:noreply, assign(socket, :material, material)}
  end

  @impl true
  def handle_info({:saved, %Inventory.Material{id: material_id}}, socket) do
    material =
      Inventory.get_material_by_id!(material_id,
        actor: socket.assigns[:current_user],
        load: material_load_opts()
      )

    {:noreply, assign(socket, :material, material)}
  end

  # If the reason starts with "PO <reference> receive", split out the reference
  # so we can link to the purchase order page. Otherwise render as plain text.
  defp render_reason(nil), do: assigns_to_text("")
  defp render_reason(reason) when is_binary(reason) do
    case Regex.run(~r/^PO\s+(\S+)\s+(.*)$/, reason) do
      [_, po_ref, rest] ->
        assigns = %{po_ref: po_ref, rest: rest}

        ~H"""
        <.link navigate={~p"/manage/purchasing/#{@po_ref}"} class="font-medium hover:underline">
          PO {@po_ref}
        </.link>
        <span class="text-stone-500">{@rest}</span>
        """

      _ ->
        assigns_to_text(reason)
    end
  end

  defp assigns_to_text(text) do
    assigns = %{text: text}

    ~H"""
    <span>{@text}</span>
    """
  end

  defp page_title(:show), do: "Show Material"
  defp page_title(:adjust), do: "Adjust Material"
  defp page_title(:edit), do: "Edit Material"
  defp page_title(:details), do: "Material Details"
  defp page_title(:allergens), do: "Material Allergens"
  defp page_title(:nutritional_facts), do: "Material Nutrition"
  defp page_title(:stock), do: "Material Stock"

  defp material_trail(material, :allergens) do
    [
      Navigation.root(:inventory),
      Navigation.resource(:material, material),
      Navigation.page(:inventory, :material_allergens, material)
    ]
  end

  defp material_trail(material, :nutritional_facts) do
    [
      Navigation.root(:inventory),
      Navigation.resource(:material, material),
      Navigation.page(:inventory, :material_nutrition, material)
    ]
  end

  defp material_trail(material, :stock) do
    [
      Navigation.root(:inventory),
      Navigation.resource(:material, material),
      Navigation.page(:inventory, :material_stock, material)
    ]
  end

  defp material_trail(material, _), do: [Navigation.root(:inventory), Navigation.resource(:material, material)]
end
