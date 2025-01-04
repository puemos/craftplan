defmodule MicrocraftWeb.InventoryLive.Index do
  @moduledoc false
  use MicrocraftWeb, :live_view

  alias Microcraft.Inventory

  @impl true
  def render(assigns) do
    ~H"""
    <.header>
      <.breadcrumb>
        <:crumb label="All Materials" path={~p"/backoffice/inventory"} current?={true} />
      </.breadcrumb>

      <:actions>
        <.link patch={~p"/backoffice/inventory/new"}>
          <.button>New Material</.button>
        </.link>
      </:actions>
    </.header>

    <.table
      id="materials"
      rows={@streams.materials}
      row_id={fn {dom_id, _} -> dom_id end}
      row_click={fn {_, material} -> JS.navigate(~p"/backoffice/inventory/#{material.id}") end}
    >
      <:empty>
        <div class="block py-4 pr-6">
          <span class={["relative"]}>
            No materials found
          </span>
        </div>
      </:empty>
      <:col :let={{_, material}} label="Name">{material.name}</:col>
      <:col :let={{_, material}} label="SKU">{material.sku}</:col>
      <:col :let={{_, material}} label="Current Stock">
        {material.current_stock || 0} {material.unit}
      </:col>
      <:col :let={{_, material}} label="Price">
        {format_money(@settings.currency, material.price)}
      </:col>

      <:action :let={{_, material}}>
        <div class="sr-only">
          <.link navigate={~p"/backoffice/inventory/#{material.id}"}>Show</.link>
        </div>
      </:action>
      <:action :let={{_, material}}>
        <.link
          phx-click={JS.push("delete", value: %{id: material.id}) |> hide("##{material.id}")}
          data-confirm="Are you sure?"
        >
          <.button size={:sm} variant={:danger}>
            Delete
          </.button>
        </.link>
      </:action>
    </.table>

    <.modal
      :if={@live_action in [:new, :edit]}
      id="material-modal"
      show
      on_cancel={JS.patch(~p"/backoffice/inventory")}
    >
      <.live_component
        module={MicrocraftWeb.InventoryLive.FormComponentMaterial}
        id={(@material && @material.id) || :new}
        current_user={@current_user}
        title={@page_title}
        action={@live_action}
        material={@material}
        settings={@settings}
        patch={~p"/backoffice/inventory"}
      />
    </.modal>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    materials =
      Inventory.list_materials!(
        actor: socket.assigns[:current_user],
        stream?: true,
        load: [:current_stock]
      )

    {:ok, stream(socket, :materials, materials)}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :new, _params) do
    socket
    |> assign(:page_title, "New Material")
    |> assign(:material, nil)
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "Inventory")
    |> assign(:material, nil)
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    material =
      Inventory.get_material_by_id!(id,
        load: [:current_stock],
        actor: socket.assigns[:current_user]
      )

    socket
    |> assign(:page_title, "Edit Material")
    |> assign(:material, material)
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    case id
         |> Inventory.get_material_by_id!()
         |> Ash.destroy(actor: socket.assigns.current_user) do
      :ok ->
        {:noreply,
         socket
         |> put_flash(:info, "Material deleted successfully")
         |> stream_delete(:materials, %{id: id})}

      {:error, _error} ->
        {:noreply, put_flash(socket, :error, "Failed to delete material.")}
    end
  end

  @impl true
  def handle_info({:saved, material}, socket) do
    material = Ash.load!(material, :current_stock)

    {:noreply, stream_insert(socket, :materials, material)}
  end
end
