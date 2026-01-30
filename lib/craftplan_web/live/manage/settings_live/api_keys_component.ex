defmodule CraftplanWeb.SettingsLive.ApiKeysComponent do
  @moduledoc false
  use CraftplanWeb, :live_component

  alias Craftplan.Accounts
  alias Craftplan.Accounts.ApiKey

  @all_resources ~w(products boms bom_components orders order_items production_batches materials lots movements suppliers purchase_orders customers settings)

  @impl true
  def render(assigns) do
    assigns =
      assigns
      |> assign_new(:show_create_modal, fn -> false end)
      |> assign_new(:raw_key, fn -> nil end)

    ~H"""
    <div class="space-y-6">
      <.header>
        <:subtitle>
          Manage API keys for programmatic access to Craftplan. Keys use scoped permissions per resource.
        </:subtitle>
        API Keys
        <:actions>
          <.button type="button" variant={:primary} phx-click="show_create_modal" phx-target={@myself}>
            <.icon name="hero-plus" class="-ml-1 mr-2 h-4 w-4" /> Create API Key
          </.button>
        </:actions>
      </.header>

      <div :if={@raw_key} class="rounded-md border border-green-300 bg-green-50 p-4">
        <div class="flex items-start gap-3">
          <.icon name="hero-key" class="mt-0.5 h-5 w-5 text-green-600" />
          <div class="flex-1">
            <p class="text-sm font-semibold text-green-800">
              API key created — copy it now, it won't be shown again
            </p>
            <div class="mt-2 flex items-center gap-2">
              <code
                id="raw-key-display"
                class="font-mono block flex-1 break-all rounded bg-white px-3 py-2 text-sm text-green-900 ring-1 ring-green-200"
              >
                {@raw_key}
              </code>
              <.button
                type="button"
                size={:sm}
                variant={:secondary}
                phx-click={
                  JS.dispatch("phx:copy", to: "#raw-key-display")
                  |> JS.set_attribute({"data-copied", "true"}, to: "#copy-key-btn")
                }
                id="copy-key-btn"
              >
                Copy
              </.button>
            </div>
          </div>
        </div>
      </div>

      <div class="rounded-md border border-gray-200 bg-white">
        <div class="p-4">
          <.table id="api-keys" rows={@api_keys} wrapper_class="mt-0">
            <:col :let={key} label="Name">{key.name}</:col>
            <:col :let={key} label="Prefix">
              <code class="text-xs">{key.prefix}...</code>
            </:col>
            <:col :let={key} label="Scopes">
              <span class="text-xs text-stone-600">
                {format_scopes_summary(key.scopes)}
              </span>
            </:col>
            <:col :let={key} label="Last used">
              {if key.last_used_at,
                do: Calendar.strftime(key.last_used_at, "%Y-%m-%d %H:%M"),
                else: "Never"}
            </:col>
            <:col :let={key} label="Status">
              <span
                :if={key.revoked_at}
                class="ring-red-600/20 inline-flex items-center rounded-full bg-red-50 px-2 py-1 text-xs font-medium text-red-700 ring-1 ring-inset"
              >
                Revoked
              </span>
              <span
                :if={is_nil(key.revoked_at)}
                class="ring-green-600/20 inline-flex items-center rounded-full bg-green-50 px-2 py-1 text-xs font-medium text-green-700 ring-1 ring-inset"
              >
                Active
              </span>
            </:col>
            <:action :let={key}>
              <.button
                :if={is_nil(key.revoked_at)}
                size={:sm}
                variant={:danger}
                phx-click={JS.push("revoke_key", value: %{id: key.id}, target: @myself)}
                data-confirm="Are you sure you want to revoke this API key? This action cannot be undone."
              >
                Revoke
              </.button>
            </:action>
            <:empty>
              <div class="py-6 text-center text-sm text-stone-500">
                No API keys yet. Create one using the button above.
              </div>
            </:empty>
          </.table>
        </div>
      </div>

      <.modal
        :if={@show_create_modal}
        id="create-api-key-modal"
        show
        title="Create API Key"
        description="Name your key and select which resources it can access"
        on_cancel={JS.push("hide_create_modal", target: @myself)}
      >
        <.simple_form
          for={@form}
          id="api-key-form"
          phx-target={@myself}
          phx-change="validate_key"
          phx-submit="create_key"
        >
          <.input field={@form[:name]} type="text" label="Key name" placeholder="e.g. Shopify sync" />

          <div class="mt-4">
            <label class="text-sm font-medium text-stone-700">Resource permissions</label>
            <p class="mb-3 text-xs text-stone-500">
              Select read and/or write access for each resource.
            </p>

            <div class="max-h-72 space-y-1 overflow-y-auto rounded border border-stone-200 p-3">
              <div :for={resource <- all_resources()} class="flex items-center justify-between py-1">
                <span class="text-sm text-stone-700">{format_resource_label(resource)}</span>
                <div class="flex gap-3">
                  <label class="flex items-center gap-1 text-xs text-stone-600">
                    <input
                      type="checkbox"
                      name={"scopes[#{resource}][read]"}
                      value="true"
                      checked={scope_checked?(@scope_selections, resource, "read")}
                      class="rounded border-stone-300"
                    /> Read
                  </label>
                  <label class="flex items-center gap-1 text-xs text-stone-600">
                    <input
                      type="checkbox"
                      name={"scopes[#{resource}][write]"}
                      value="true"
                      checked={scope_checked?(@scope_selections, resource, "write")}
                      class="rounded border-stone-300"
                    /> Write
                  </label>
                </div>
              </div>
            </div>
          </div>

          <:actions>
            <.button variant={:primary} phx-disable-with="Creating...">Create Key</.button>
          </:actions>
        </.simple_form>
      </.modal>
    </div>
    """
  end

  @impl true
  def update(assigns, socket) do
    api_keys = load_api_keys(assigns.current_user)
    form = new_api_key_form(assigns.current_user)

    {:ok,
     socket
     |> assign(assigns)
     |> assign(:api_keys, api_keys)
     |> assign(:form, form)
     |> assign(:show_create_modal, false)
     |> assign(:raw_key, nil)
     |> assign(:scope_selections, %{})}
  end

  @impl true
  def handle_event("show_create_modal", _, socket) do
    {:noreply, assign(socket, :show_create_modal, true)}
  end

  @impl true
  def handle_event("hide_create_modal", _, socket) do
    {:noreply, assign(socket, :show_create_modal, false)}
  end

  @impl true
  def handle_event("validate_key", %{"api_key" => params} = full_params, socket) do
    form = AshPhoenix.Form.validate(socket.assigns.form, params)
    scope_selections = parse_scope_params(full_params)

    {:noreply,
     socket
     |> assign(:form, form)
     |> assign(:scope_selections, scope_selections)}
  end

  @impl true
  def handle_event("create_key", %{"api_key" => params} = full_params, socket) do
    scopes = build_scopes_map(full_params)
    params = Map.put(params, "scopes", scopes)

    case AshPhoenix.Form.submit(socket.assigns.form, params: params) do
      {:ok, api_key} ->
        raw_key = Map.get(api_key, :__raw_key__)
        api_keys = load_api_keys(socket.assigns.current_user)

        {:noreply,
         socket
         |> assign(:api_keys, api_keys)
         |> assign(:form, new_api_key_form(socket.assigns.current_user))
         |> assign(:show_create_modal, false)
         |> assign(:raw_key, raw_key)
         |> assign(:scope_selections, %{})
         |> put_flash(:info, "API key created")}

      {:error, form} ->
        {:noreply, assign(socket, :form, form)}
    end
  end

  @impl true
  def handle_event("revoke_key", %{"id" => id}, socket) do
    api_key = Ash.get!(ApiKey, id, authorize?: false)
    Accounts.revoke_api_key(api_key, actor: socket.assigns.current_user)

    api_keys = load_api_keys(socket.assigns.current_user)

    {:noreply,
     socket
     |> assign(:api_keys, api_keys)
     |> put_flash(:info, "API key revoked")}
  end

  defp load_api_keys(user) do
    case Accounts.list_api_keys_for_user(%{user_id: user.id}, actor: user) do
      {:ok, keys} -> keys
      _ -> []
    end
  end

  defp new_api_key_form(user) do
    ApiKey
    |> AshPhoenix.Form.for_create(:create, actor: user, as: "api_key")
    |> to_form()
  end

  defp all_resources, do: @all_resources

  defp format_resource_label(resource) do
    resource
    |> String.replace("_", " ")
    |> String.capitalize()
  end

  defp format_scopes_summary(scopes) when is_map(scopes) do
    count = map_size(scopes)

    case count do
      0 -> "No access"
      n -> "#{n} resource#{if n > 1, do: "s"}"
    end
  end

  defp format_scopes_summary(_), do: "No access"

  defp scope_checked?(selections, resource, permission) do
    get_in(selections, [resource, permission]) == true
  end

  defp parse_scope_params(%{"scopes" => scopes}) when is_map(scopes) do
    Map.new(scopes, fn {resource, perms} ->
      {resource,
       %{
         "read" => Map.get(perms, "read") == "true",
         "write" => Map.get(perms, "write") == "true"
       }}
    end)
  end

  defp parse_scope_params(_), do: %{}

  defp build_scopes_map(%{"scopes" => scopes}) when is_map(scopes) do
    Enum.reduce(scopes, %{}, fn {resource, perms}, acc ->
      permissions =
        []
        |> then(fn p -> if Map.get(perms, "read") == "true", do: ["read" | p], else: p end)
        |> then(fn p -> if Map.get(perms, "write") == "true", do: ["write" | p], else: p end)

      if permissions == [] do
        acc
      else
        Map.put(acc, resource, permissions)
      end
    end)
  end

  defp build_scopes_map(_), do: %{}
end
