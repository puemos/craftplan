defmodule CraftplanWeb.PurchasingLive.PurchaseOrderItemFormComponent do
  @moduledoc false
  use CraftplanWeb, :live_component

  alias AshPhoenix.Form
  alias Craftplan.Inventory

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.simple_form
        for={@form}
        id="purchase-order-item-form"
        phx-target={@myself}
        phx-change="validate"
        phx-submit="save"
      >
        <.input field={@form[:purchase_order_id]} type="hidden" />
        <.input
          field={@form[:material_id]}
          type="select"
          label="Material"
          options={for m <- @materials, do: {m.name, m.id}}
        />
        <div class="grid grid-cols-1 gap-4 sm:grid-cols-2">
          <.input field={@form[:quantity]} type="number" label="Quantity" step="0.001" min="0" />
          <.input field={@form[:unit_price]} type="number" label="Unit Price" step="0.001" min="0" />
        </div>
        <:actions>
          <.button phx-disable-with="Adding...">Add Item</.button>
        </:actions>
      </.simple_form>
    </div>
    """
  end

  @impl true
  def update(assigns, socket) do
    {:ok, socket |> assign(assigns) |> assign_form()}
  end

  @impl true
  def handle_event("validate", %{"purchase_order_item" => params}, socket) do
    {:noreply, assign(socket, form: Form.validate(socket.assigns.form, params))}
  end

  @impl true
  def handle_event("save", %{"purchase_order_item" => params}, socket) do
    case Form.submit(socket.assigns.form, params: params) do
      {:ok, item} ->
        send(self(), {:po_item_saved, item})

        {:noreply, socket |> put_flash(:info, "Item added") |> push_patch(to: socket.assigns.patch)}

      {:error, form} ->
        {:noreply, assign(socket, :form, form)}
    end
  end

  defp assign_form(%{assigns: %{purchase_order_item: item, po_id: po_id}} = socket) do
    form =
      if item do
        Form.for_update(item, :update,
          as: "purchase_order_item",
          actor: socket.assigns.current_user
        )
      else
        Form.for_create(Inventory.PurchaseOrderItem, :create,
          as: "purchase_order_item",
          actor: socket.assigns.current_user,
          params: %{purchase_order_id: po_id}
        )
      end

    assign(socket, form: to_form(form))
  end
end
