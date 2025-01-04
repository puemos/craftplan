defmodule MicrocraftWeb.CustomerLive.FormComponent do
  @moduledoc false
  use MicrocraftWeb, :live_component

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.header>
        {@title}
        <:subtitle>Use this form to manage customer records in your database.</:subtitle>
      </.header>

      <.simple_form
        for={@form}
        id="customer-form"
        phx-target={@myself}
        phx-change="validate"
        phx-submit="save"
      >
        <div class="mt-4 space-y-8 bg-white">
          <.input
            field={@form[:type]}
            type="segmented"
            options={[{"Individual", :individual}, {"Company", :company}]}
            value={@form[:type].value || :individual}
          />

          <div class="space-y-4">
            <div class="flex flex-row space-x-4">
              <.input field={@form[:first_name]} type="text" label="First name" />
              <.input field={@form[:last_name]} type="text" label="Last name" />
            </div>
            <.input field={@form[:email]} type="email" label="Email" />
            <.input field={@form[:phone]} type="tel" label="Phone" />
          </div>

          <div class="flex flex-col space-y-4">
            <div class="space-y-4">
              <label class="text-sm font-semibold leading-6 text-zinc-800">
                Billing Address
              </label>
              <.inputs_for :let={f_addr} field={@form[:billing_address]}>
                <div class="grid grid-cols-1 gap-4 sm:grid-cols-2">
                  <.input field={f_addr[:street]} type="text" label="Street" />
                  <.input field={f_addr[:city]} type="text" label="City" />
                  <.input field={f_addr[:state]} type="text" label="State" />
                  <.input field={f_addr[:zip]} type="text" label="Postal Code" />
                  <.input field={f_addr[:country]} type="text" label="Country" />
                </div>
              </.inputs_for>
            </div>
            <div class="space-y-4">
              <label class="text-sm font-semibold leading-6 text-zinc-800">
                Shipping Address
              </label>
              <.inputs_for :let={f_addr} field={@form[:shipping_address]}>
                <div class="grid grid-cols-1 gap-4 sm:grid-cols-2">
                  <.input field={f_addr[:street]} type="text" label="Street" />
                  <.input field={f_addr[:city]} type="text" label="City" />
                  <.input field={f_addr[:state]} type="text" label="State" />
                  <.input field={f_addr[:zip]} type="text" label="Postal Code" />
                  <.input field={f_addr[:country]} type="text" label="Country" />
                </div>
              </.inputs_for>
            </div>
          </div>
        </div>

        <:actions>
          <.button phx-disable-with="Saving...">Save Customer</.button>
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
  def handle_event("validate", %{"customer" => customer_params}, socket) do
    {:noreply,
     assign(socket, form: AshPhoenix.Form.validate(socket.assigns.form, customer_params))}
  end

  def handle_event("save", %{"customer" => customer_params}, socket) do
    case AshPhoenix.Form.submit(socket.assigns.form, params: customer_params) do
      {:ok, customer} ->
        notify_parent({:saved, customer})

        {:noreply,
         socket
         |> put_flash(:info, "Customer #{socket.assigns.form.source.type}d successfully")
         |> push_patch(to: socket.assigns.patch)}

      {:error, form} ->
        {:noreply, assign(socket, form: form)}
    end
  end

  defp notify_parent(msg), do: send(self(), {__MODULE__, msg})

  defp assign_form(%{assigns: %{customer: customer}} = socket) do
    form =
      if customer do
        AshPhoenix.Form.for_update(customer, :update,
          as: "customer",
          actor: socket.assigns.current_user,
          forms: [
            billing_address: [
              data: customer.billing_address || %{},
              create_action: :create,
              update_action: :update
            ],
            shipping_address: [
              data: customer.shipping_address || %{},
              create_action: :create,
              update_action: :update
            ]
          ]
        )
      else
        AshPhoenix.Form.for_create(Microcraft.CRM.Customer, :create,
          as: "customer",
          actor: socket.assigns.current_user,
          forms: [
            billing_address: [
              data: %{},
              create_action: :create,
              update_action: :update
            ],
            shipping_address: [
              data: %{},
              create_action: :create,
              update_action: :update
            ]
          ]
        )
      end

    assign(socket, form: to_form(form))
  end
end
