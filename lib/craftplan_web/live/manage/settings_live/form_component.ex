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
        <div class="space-y-8">
          <section
            id="general-settings"
            aria-labelledby="general-settings-title"
            class="rounded-lg border border-stone-200 bg-stone-50"
          >
            <div class="border-b border-stone-200 px-4 py-3">
              <h3 id="general-settings-title" class="text-base font-semibold text-stone-800">
                General
              </h3>
              <p class="mt-1 text-sm text-stone-600">
                Set the default currency used across orders, invoices, and reports.
              </p>
            </div>
            <div class="space-y-4 p-4">
              <.input
                field={@form[:currency]}
                type="select"
                options={currency_options()}
                label="Default currency"
              />
            </div>
          </section>

          <section
            id="tax-settings"
            aria-labelledby="tax-settings-title"
            class="rounded-lg border border-stone-200 bg-stone-50"
          >
            <div class="border-b border-stone-200 px-4 py-3">
              <h3 id="tax-settings-title" class="text-base font-semibold text-stone-800">
                Tax &amp; Pricing
              </h3>
              <p class="mt-1 text-sm text-stone-600">
                Choose how tax is applied and define a default rate. Rates are decimal, e.g. 0.21 for 21%.
              </p>
            </div>
            <div class="grid grid-cols-1 gap-4 p-4 sm:grid-cols-2">
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
                label="Tax rate"
                placeholder="0.21"
              />
            </div>
          </section>

          <section
            id="fulfillment-settings"
            aria-labelledby="fulfillment-settings-title"
            class="rounded-lg border border-stone-200 bg-stone-50"
          >
            <div class="border-b border-stone-200 px-4 py-3">
              <h3 id="fulfillment-settings-title" class="text-base font-semibold text-stone-800">
                Fulfillment &amp; Capacity
              </h3>
              <p class="mt-1 text-sm text-stone-600">
                Configure how orders are fulfilled and the capacity rules that inform scheduling.
              </p>
            </div>
            <div class="space-y-6 p-4">
              <div class="grid grid-cols-1 gap-4 sm:grid-cols-3">
                <.input field={@form[:offers_pickup]} type="checkbox" label="Offer pickup" />
                <.input field={@form[:offers_delivery]} type="checkbox" label="Offer delivery" />
                <.input
                  field={@form[:shipping_flat]}
                  type="number"
                  step="0.01"
                  min="0"
                  label="Flat shipping"
                />
              </div>
              <div class="grid grid-cols-1 gap-4 sm:grid-cols-2">
                <.input
                  field={@form[:lead_time_days]}
                  type="number"
                  min="0"
                  label="Lead time (days)"
                  placeholder="e.g. 2"
                />
                <.input
                  field={@form[:daily_capacity]}
                  type="number"
                  min="0"
                  label="Daily capacity"
                  placeholder="0 for unlimited"
                />
              </div>
            </div>
          </section>
          <section
            id="email-sender-settings"
            aria-labelledby="email-sender-settings-title"
            class="rounded-lg border border-stone-200 bg-stone-50"
          >
            <div class="border-b border-stone-200 px-4 py-3">
              <h3 id="email-sender-settings-title" class="text-base font-semibold text-stone-800">
                Email Sender
              </h3>
              <p class="mt-1 text-sm text-stone-600">
                Configure the sender name and address used for outgoing emails.
              </p>
            </div>
            <div class="grid grid-cols-1 gap-4 p-4 sm:grid-cols-2">
              <.input
                field={@form[:email_from_name]}
                type="text"
                label="Sender name"
                placeholder="Craftplan"
              />
              <.input
                field={@form[:email_from_address]}
                type="email"
                label="Sender email"
                placeholder="noreply@craftplan.app"
              />
            </div>
          </section>

          <section
            id="email-delivery-settings"
            aria-labelledby="email-delivery-settings-title"
            class="rounded-lg border border-stone-200 bg-stone-50"
          >
            <div class="border-b border-stone-200 px-4 py-3">
              <h3 id="email-delivery-settings-title" class="text-base font-semibold text-stone-800">
                Email Delivery
              </h3>
              <p class="mt-1 text-sm text-stone-600">
                Choose an email provider and configure its credentials.
              </p>
            </div>
            <div class="space-y-4 p-4">
              <.input
                field={@form[:email_provider]}
                type="select"
                options={provider_options()}
                label="Provider"
              />

              <%= case selected_provider(@form) do %>
                <% :smtp -> %>
                  <div class="grid grid-cols-1 gap-4 sm:grid-cols-2">
                    <.input
                      field={@form[:smtp_host]}
                      type="text"
                      label="SMTP host"
                      placeholder="smtp.example.com"
                    />
                    <.input
                      field={@form[:smtp_port]}
                      type="number"
                      label="SMTP port"
                      placeholder="587"
                    />
                  </div>
                  <div class="grid grid-cols-1 gap-4 sm:grid-cols-2">
                    <.input
                      field={@form[:smtp_username]}
                      type="text"
                      label="Username"
                      placeholder="user@example.com"
                    />
                    <.input
                      field={@form[:smtp_password]}
                      type="password"
                      label="Password"
                      placeholder="••••••••"
                    />
                  </div>
                  <.input
                    field={@form[:smtp_tls]}
                    type="select"
                    options={[
                      {"If available", :if_available},
                      {"Always", :always},
                      {"Never", :never}
                    ]}
                    label="TLS mode"
                  />
                <% provider when provider in [:sendgrid, :postmark, :brevo] -> %>
                  <.input
                    field={@form[:email_api_key]}
                    type="password"
                    label="API key"
                    placeholder="••••••••"
                  />
                <% :mailgun -> %>
                  <div class="grid grid-cols-1 gap-4 sm:grid-cols-2">
                    <.input
                      field={@form[:email_api_key]}
                      type="password"
                      label="API key"
                      placeholder="••••••••"
                    />
                    <.input
                      field={@form[:email_api_domain]}
                      type="text"
                      label="Domain"
                      placeholder="mg.example.com"
                    />
                  </div>
                <% :amazon_ses -> %>
                  <div class="grid grid-cols-1 gap-4 sm:grid-cols-2">
                    <.input
                      field={@form[:email_api_key]}
                      type="password"
                      label="Access key"
                      placeholder="AKIA..."
                    />
                    <.input
                      field={@form[:email_api_secret]}
                      type="password"
                      label="Secret key"
                      placeholder="••••••••"
                    />
                  </div>
                  <.input
                    field={@form[:email_api_region]}
                    type="select"
                    options={ses_region_options()}
                    label="Region"
                  />
                <% _ -> %>
              <% end %>
            </div>
          </section>

          <section
            id="forecasting-settings"
            aria-labelledby="forecasting-settings-title"
            class="rounded-lg border border-stone-200 bg-stone-50"
          >
            <div class="border-b border-stone-200 px-4 py-3">
              <h3 id="forecasting-settings-title" class="text-base font-semibold text-stone-800">
                Inventory Forecasting
              </h3>
              <p class="mt-1 text-sm text-stone-600">
                Fine-tune how the reorder planner calculates safety stock, reorder points, and suggested quantities.
              </p>
            </div>
            <div class="space-y-6 p-4">
              <div class="grid grid-cols-1 gap-4 sm:grid-cols-3">
                <.input
                  field={@form[:forecast_lookback_days]}
                  type="number"
                  min="7"
                  max="365"
                  label="Lookback days"
                  placeholder="42"
                />
                <.input
                  field={@form[:forecast_default_horizon_days]}
                  type="number"
                  min="7"
                  max="90"
                  label="Default horizon (days)"
                  placeholder="14"
                />
                <.input
                  field={@form[:forecast_min_samples]}
                  type="number"
                  min="3"
                  max="100"
                  label="Min samples for variability"
                  placeholder="10"
                />
              </div>
              <div class="grid grid-cols-1 gap-4 sm:grid-cols-3">
                <.input
                  field={@form[:forecast_actual_weight]}
                  type="number"
                  step="0.01"
                  min="0"
                  max="1"
                  label="Actual usage weight"
                  placeholder="0.6"
                />
                <.input
                  field={@form[:forecast_planned_weight]}
                  type="number"
                  step="0.01"
                  min="0"
                  max="1"
                  label="Planned usage weight"
                  placeholder="0.4"
                />
                <.input
                  field={@form[:forecast_default_service_level]}
                  type="number"
                  step="0.01"
                  min="0.8"
                  max="0.999"
                  label="Default service level"
                  placeholder="0.95"
                />
              </div>
              <p class="text-xs text-stone-500">
                Actual and planned weights should sum to 1. Higher service levels increase safety stock.
              </p>
            </div>
          </section>
        </div>

        <:actions>
          <.button variant={:primary} phx-disable-with="Saving...">Save Settings</.button>
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
    setting_params = %{
      setting_params
      | "shipping_flat" => Money.new!(setting_params["shipping_flat"], String.to_atom(setting_params["currency"]))
    }

    {:noreply, assign(socket, form: AshPhoenix.Form.validate(socket.assigns.form, setting_params))}
  end

  def handle_event("save", %{"settings" => setting_params}, socket) do
    setting_params = %{
      setting_params
      | "shipping_flat" => Money.new!(setting_params["shipping_flat"], String.to_atom(setting_params["currency"]))
    }

    case AshPhoenix.Form.submit(socket.assigns.form, params: setting_params) do
      {:ok, settings} ->
        Craftplan.Mailer.apply_settings(settings)
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

  defp selected_provider(form) do
    value = Phoenix.HTML.Form.input_value(form, :email_provider)

    case value do
      v when is_atom(v) and not is_nil(v) -> v
      v when is_binary(v) and v != "" -> String.to_existing_atom(v)
      _ -> :smtp
    end
  end

  defp provider_options do
    [
      {"SMTP", :smtp},
      {"SendGrid", :sendgrid},
      {"Mailgun", :mailgun},
      {"Postmark", :postmark},
      {"Brevo (Sendinblue)", :brevo},
      {"Amazon SES", :amazon_ses}
    ]
  end

  defp ses_region_options do
    [
      {"US East (N. Virginia)", "us-east-1"},
      {"US West (Oregon)", "us-west-2"},
      {"EU (Ireland)", "eu-west-1"},
      {"EU (Frankfurt)", "eu-central-1"},
      {"Asia Pacific (Mumbai)", "ap-south-1"},
      {"Asia Pacific (Sydney)", "ap-southeast-2"}
    ]
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
