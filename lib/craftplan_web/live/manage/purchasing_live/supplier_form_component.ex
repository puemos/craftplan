defmodule CraftplanWeb.PurchasingLive.SupplierFormComponent do
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
        id="supplier-form"
        phx-target={@myself}
        phx-change="validate"
        phx-submit="save"
      >
        <.input field={@form[:name]} type="text" label="Name" />
        <div class="grid grid-cols-1 gap-4 sm:grid-cols-2">
          <.input field={@form[:contact_name]} type="text" label="Contact Name" />
          <.input field={@form[:contact_phone]} type="text" label="Contact Phone" />
        </div>
        <.input field={@form[:contact_email]} type="email" label="Contact Email" />
        <fieldset class="space-y-4 rounded-lg border border-stone-200 p-4">
          <legend class="px-1 text-sm font-medium text-stone-700">Supplier address</legend>
          <.input
            name="supplier[address][street]"
            id="supplier-address-street"
            value={address_value(@supplier, :street)}
            type="text"
            label="Street"
          />
          <div class="grid grid-cols-1 gap-4 sm:grid-cols-2">
            <.input
              name="supplier[address][city]"
              id="supplier-address-city"
              value={address_value(@supplier, :city)}
              type="text"
              label="City"
            />
            <.input
              name="supplier[address][state]"
              id="supplier-address-state"
              value={address_value(@supplier, :state)}
              type="text"
              label="State / Region"
            />
            <.input
              name="supplier[address][zip]"
              id="supplier-address-zip"
              value={address_value(@supplier, :zip)}
              type="text"
              label="Postal code"
            />
            <.input
              name="supplier[address][country]"
              id="supplier-address-country"
              value={address_value(@supplier, :country)}
              type="text"
              label="Country"
            />
          </div>
        </fieldset>
        <.input field={@form[:notes]} type="textarea" label="Notes" />

        <:actions>
          <.button variant={:primary} phx-disable-with="Saving...">Save Supplier</.button>
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
  def handle_event("validate", %{"supplier" => params}, socket) do
    {:noreply, assign(socket, form: Form.validate(socket.assigns.form, params))}
  end

  @impl true
  def handle_event("save", %{"supplier" => params}, socket) do
    case Form.submit(socket.assigns.form, params: params) do
      {:ok, supplier} ->
        send(self(), {:supplier_saved, supplier})

        {:noreply, socket |> put_flash(:info, "Supplier saved") |> push_patch(to: socket.assigns.patch)}

      {:error, form} ->
        {:noreply, assign(socket, :form, form)}
    end
  end

  defp assign_form(%{assigns: %{supplier: supplier}} = socket) do
    form =
      if supplier do
        Form.for_update(supplier, :update,
          as: "supplier",
          actor: socket.assigns.current_user,
          transform_params: &drop_blank_address/2
        )
      else
        Form.for_create(Inventory.Supplier, :create,
          as: "supplier",
          actor: socket.assigns.current_user,
          transform_params: &drop_blank_address/2
        )
      end

    assign(socket, form: to_form(form))
  end

  defp drop_blank_address(params, _stage) do
    address = Map.get(params, "address") || Map.get(params, :address)

    if is_map(address) and Enum.all?(address, fn {_key, value} -> value in [nil, ""] end) do
      params |> Map.delete("address") |> Map.delete(:address)
    else
      params
    end
  end

  defp address_value(nil, _field), do: ""
  defp address_value(%{address: nil}, _field), do: ""
  defp address_value(%{address: address}, field), do: Map.get(address, field, "")
end
