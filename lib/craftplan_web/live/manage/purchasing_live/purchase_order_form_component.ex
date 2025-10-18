defmodule CraftplanWeb.PurchasingLive.PurchaseOrderFormComponent do
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
        id="purchase-order-form"
        phx-target={@myself}
        phx-change="validate"
        phx-submit="save"
      >
        <.input
          field={@form[:supplier_id]}
          type="select"
          label="Supplier"
          options={for s <- @suppliers, do: {s.name, s.id}}
        />

        <.input
          field={@form[:status]}
          type="select"
          label="Status"
          options={[{"Draft", :draft}, {"Ordered", :ordered}, {"Received", :received}]}
        />

        <.input field={@form[:ordered_at]} type="datetime-local" label="Ordered At" />

        <:actions>
          <.button phx-disable-with="Saving...">Save Purchase Order</.button>
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
  def handle_event("validate", %{"purchase_order" => params}, socket) do
    {:noreply, assign(socket, form: Form.validate(socket.assigns.form, params))}
  end

  @impl true
  def handle_event("save", %{"purchase_order" => params}, socket) do
    case Form.submit(socket.assigns.form, params: params) do
      {:ok, po} ->
        send(self(), {:po_saved, po})

        {:noreply,
         socket
         |> put_flash(:info, "Purchase order saved")
         |> push_patch(to: socket.assigns.patch)}

      {:error, form} ->
        {:noreply, assign(socket, :form, form)}
    end
  end

  defp assign_form(%{assigns: %{purchase_order: po}} = socket) do
    form =
      if po do
        Form.for_update(po, :update,
          as: "purchase_order",
          actor: socket.assigns.current_user
        )
      else
        Form.for_create(Inventory.PurchaseOrder, :create,
          as: "purchase_order",
          actor: socket.assigns.current_user
        )
      end

    assign(socket, form: to_form(form))
  end
end
