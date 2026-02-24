defmodule CraftplanWeb.InventoryLive.FormComponentMaterial do
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
        id="material-form"
        phx-target={@myself}
        phx-change="validate"
        phx-submit="save"
      >
        <.input field={@form[:name]} type="text" label="Name" />
        <.input field={@form[:sku]} type="text" label="SKU" />
        <div class="grid grid-cols-1 gap-4 sm:grid-cols-2">
          <.input field={@form[:price]} type="text" label="Price" class="h-24 w-full" />

          <.radio_card id="unit" field={@form[:unit]} cols="two" variant="bordered">
            <:radio
              value="gram"
              title="Gram"
              checked={
                if @form[:unit].value == :gram || @form[:unit].value == nil do
                  true
                end
              }
            >
            </:radio>
            <:radio
              value="milliliter"
              title="Milliliter"
              checked={
                if @form[:unit].value == :milliliter do
                  true
                end
              }
            >
            </:radio>
            <:radio
              value="piece"
              title="Piece"
              checked={
                if @form[:unit].value == :piece do
                  true
                end
              }
            >
            </:radio>
          </.radio_card>
        </div>

        <.input
          field={@form[:minimum_stock]}
          type="number"
          label="Minimum Stock"
          inline_label={@form[:unit].value || :gram}
          step="0.001"
          min="0"
        />
        <.input
          field={@form[:maximum_stock]}
          inline_label={@form[:unit].value || :gram}
          type="number"
          label="Maximum Stock"
          step="0.001"
          min="0"
        />

        <.input
          field={@form[:location_id]}
          type="select"
          options={Enum.map(@locations, &{&1.name, &1.id})}
          label="Material Location"
        />

        <:actions>
          <.button variant={:primary} phx-disable-with="Saving...">Save Material</.button>
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
  def handle_event("validate", %{"material" => material_params}, socket) do
    {:noreply, assign(socket, form: Form.validate(socket.assigns.form, material_params))}
  end

  def handle_event("save", %{"material" => material_params}, socket) do
    currency = Craftplan.Settings.get_settings!().currency

    price = Money.parse(material_params["price"], default_currency: currency)

    material_params = Map.replace(material_params, "price", price)

    case Form.submit(socket.assigns.form, params: material_params) do
      {:ok, material} ->
        send(self(), {:saved, material})

        {:noreply,
         socket
         |> put_flash(:info, "Material #{socket.assigns.form.source.type}d successfully")
         |> push_patch(to: socket.assigns.patch)}

      {:error, form} ->
        {:noreply, assign(socket, :form, form)}
    end
  end

  defp assign_form(%{assigns: %{material: material}} = socket) do
    form =
      if material do
        Form.for_update(material, :update,
          as: "material",
          actor: socket.assigns.current_user
        )
      else
        Form.for_create(Inventory.Material, :create,
          as: "material",
          actor: socket.assigns.current_user
        )
      end

    socket |> assign(form: to_form(form)) |> assign(locations: Inventory.list_locations!())
  end
end
