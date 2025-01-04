defmodule MicrocraftWeb.InventoryLive.FormComponentMovement do
  @moduledoc false
  use MicrocraftWeb, :live_component

  alias AshPhoenix.Form
  alias Microcraft.Inventory

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.header>
        <:subtitle>Use this form to manage movement records in your database.</:subtitle>
      </.header>

      <.simple_form
        for={@form}
        id="movement-movment-form"
        phx-target={@myself}
        phx-change="validate"
        phx-submit="save"
      >
        <.input field={@form[:quantity]} type="number" label="Quantity" inline_label={@material.unit} />
        <.input field={@form[:material_id]} type="hidden" value={@material.id} />

        <:actions>
          <.button phx-disable-with="Saving...">Record movement</.button>
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
  def handle_event("validate", %{"movement" => movement_params}, socket) do
    {:noreply, assign(socket, form: Form.validate(socket.assigns.form, movement_params))}
  end

  def handle_event("save", %{"movement" => movement_params}, socket) do
    case Form.submit(socket.assigns.form, params: movement_params) do
      {:ok, movement} ->
        send(self(), {:saved, movement})

        {:noreply,
         socket
         |> put_flash(:info, "Material #{socket.assigns.form.source.type}d successfully")
         |> push_patch(to: socket.assigns.patch)}

      {:error, form} ->
        {:noreply, assign(socket, :form, form)}
    end
  end

  defp assign_form(socket) do
    form =
      AshPhoenix.Form.for_create(Inventory.Movement, :adjust_stock,
        as: "movement",
        actor: socket.assigns.current_user
      )

    assign(socket, form: to_form(form))
  end
end
