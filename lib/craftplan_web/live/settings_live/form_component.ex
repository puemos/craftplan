defmodule CraftplanWeb.SettingsLive.FormComponent do
  @moduledoc false
  use CraftplanWeb, :live_component

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.simple_form
        for={@form}
        id="settings-form"
        phx-target={@myself}
        phx-change="validate"
        phx-submit="save"
      >
        <.input
          field={@form[:currency]}
          type="select"
          options={currency_options()}
          label="Default currency"
        />
        <div class="grid grid-cols-1 gap-4 sm:grid-cols-2">
          <.input
            field={@form[:tax_mode]}
            type="select"
            options={[
              {"Exclusive (add tax)", :exclusive},
              {"Inclusive (price includes tax)", :inclusive}
            ]}
            label="Tax mode"
          />
          <.input
            field={@form[:tax_rate]}
            type="number"
            step="0.001"
            min="0"
            label="Tax rate (e.g., 0.21)"
          />
        </div>

        <div class="grid grid-cols-1 gap-4 sm:grid-cols-3">
          <.input field={@form[:offers_pickup]} type="checkbox" label="Offer Pickup" />
          <.input field={@form[:offers_delivery]} type="checkbox" label="Offer Delivery" />
          <.input
            field={@form[:shipping_flat]}
            type="number"
            step="0.01"
            min="0"
            label="Flat Shipping"
          />
        </div>

        <div class="grid grid-cols-1 gap-4 sm:grid-cols-2">
          <.input field={@form[:lead_time_days]} type="number" min="0" label="Lead time (days)" />
          <.input
            field={@form[:daily_capacity]}
            type="number"
            min="0"
            label="Daily capacity (0=unlimited)"
          />
        </div>
        <:actions>
          <.button phx-disable-with="Saving...">Save Settings</.button>
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
  def handle_event("validate", %{"settings" => setting_params}, socket) do
    {:noreply, assign(socket, form: AshPhoenix.Form.validate(socket.assigns.form, setting_params))}
  end

  def handle_event("save", %{"settings" => setting_params}, socket) do
    case AshPhoenix.Form.submit(socket.assigns.form, params: setting_params) do
      {:ok, settings} ->
        notify_parent({:saved, settings})

        {:noreply,
         socket
         |> put_flash(:info, "Settings updated successfully")
         |> push_patch(to: socket.assigns.patch)}

      {:error, form} ->
        {:noreply, assign(socket, form: form)}
    end
  end

  defp notify_parent(msg), do: send(self(), {__MODULE__, msg})

  defp assign_form(%{assigns: %{settings: settings}} = socket) do
    form =
      AshPhoenix.Form.for_update(settings, :update,
        as: "settings",
        actor: socket.assigns.current_user
      )

    assign(socket, form: to_form(form))
  end

  defp currency_options do
    [{"US Dollar", :USD}, {"Euro", :EUR}] ++
      (Craftplan.Types.Currency.values()
       |> Enum.reject(fn code -> code in [:USD, :EUR] end)
       |> Enum.map(fn code ->
         case Money.Currency.currency_for_code(code) do
           {:ok, currency} -> {currency.name, code}
           _ -> nil
         end
       end)
       |> Enum.reject(&is_nil/1))
  end
end
