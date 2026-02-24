defmodule CraftplanWeb.SettingsLive.ServicesComponent do
  @moduledoc false
  use CraftplanWeb, :live_component

  alias Craftplan.Settings
  alias Craftplan.Settings.Services

  @impl true
  def render(assigns) do
    assigns = assign_new(assigns, :show_modal, fn -> false end)

    ~H"""
    <div class="space-y-6">
      <.header>
        <:subtitle>
          Search and manage the services available across your products and materials.
        </:subtitle>
        Services
      </.header>

      <div class="flex flex-col gap-6 lg:flex-row">
        <div class="flex-1">
          <div class="rounded-md border border-gray-200 bg-white">
            <div class="border-t border-stone-200 px-4 py-4">
              <form
                id="service-filter"
                phx-change="filter_services"
                phx-submit="filter_services"
                phx-target={@myself}
                class="space-y-4"
              >
                <label class="sr-only text-sm font-medium text-stone-700" for="service-filter-query">
                  Search Services
                </label>
                <input
                  id="service-filter-query"
                  name="query"
                  type="search"
                  value={@search_query}
                  placeholder="Type to filter by name..."
                  phx-debounce="300"
                  class="w-full rounded-md border border-stone-300 bg-white px-3 py-2 text-sm text-stone-900 transition focus:border-primary-400 focus:ring-primary-200/60 focus:outline-none focus:ring"
                />
              </form>
            </div>

            <div class="-mt-10 p-4">
              <.table id="services" rows={@visible_services} wrapper_class="mt-0">
                <:col :let={service} label="Name">{service.name}</:col>
                <:action :let={service}>
                  <.link
                    phx-click={JS.push("delete", value: %{id: service.id}, target: @myself)}
                    data-confirm="Are you sure you want to delete this service? This action cannot be undone."
                  >
                    <.button size={:sm} variant={:danger}>
                      Delete
                    </.button>
                  </.link>
                </:action>
                <:empty>
                  <div class="py-6 text-center text-sm text-stone-500">
                    {if String.trim(@search_query) == "" do
                      "No services yet. Add your first service from the manage panel."
                    else
                      "No services match your search."
                    end}
                  </div>
                </:empty>
              </.table>
            </div>
          </div>
        </div>

        <aside class="lg:w-80">
          <div class="space-y-4 rounded-md border border-gray-200 bg-white p-4">
            <h3 class="text-sm font-semibold text-stone-800">Manage</h3>
            <p class="text-sm text-stone-600">
              Create new services or remove ones you no longer track. Changes apply immediately across Craftplan.
            </p>
            <.button
              type="button"
              variant={:primary}
              class="w-full justify-center"
              phx-click="show_add_modal"
              phx-target={@myself}
            >
              <.icon name="hero-plus" class="mr-2 h-4 w-4" /> Add service
            </.button>
          </div>
        </aside>
      </div>

      <.modal
        :if={@show_modal}
        id="add-service-modal"
        show
        title="Add New Service"
        description="Enter the name of the service you want to add"
        on_cancel={JS.push("hide_modal", target: @myself)}
      >
        <.simple_form
          for={@form}
          id="service-form"
          phx-target={@myself}
          phx-change="validate"
          phx-submit="save"
        >
          <.input field={@form[:name]} type="text" label="service name" />
          <:actions>
            <.button variant={:primary} phx-disable-with="Saving...">Save service</.button>
          </:actions>
        </.simple_form>
      </.modal>
    </div>
    """
  end

  @impl true
  def update(assigns, socket) do
    services = Settings.list_services!()
    form = new_service_form(assigns.current_user)
    search_query = Map.get(socket.assigns, :search_query, "")

    {:ok,
     socket
     |> assign(assigns)
     |> assign(:services, services)
     |> assign(:search_query, search_query)
     |> assign(:visible_services, filter_services(services, search_query))
     |> assign(:form, form)
     |> assign(:show_modal, false)}
  end

  @impl true
  def handle_event("validate", %{"services" => service_params}, socket) do
    form = AshPhoenix.Form.validate(socket.assigns.form, service_params)
    {:noreply, assign(socket, :form, form)}
  end

  @impl true
  def handle_event("save", %{"services" => service_params}, socket) do
    case AshPhoenix.Form.submit(socket.assigns.form, params: service_params) do
      {:ok, _service} ->
        # Notify parent to reload services
        send(self(), {:saved_services, nil})

        services = Settings.list_services!()

        socket =
          socket
          |> assign(:form, new_service_form(socket.assigns.current_user))
          |> assign(:show_modal, false)
          |> assign(:services, services)
          |> assign_filtered_services(socket.assigns.search_query)

        {:noreply, put_flash(socket, :info, "service added successfully")}

      {:error, form} ->
        {:noreply, assign(socket, :form, form)}
    end
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    service = Settings.get_service_by_id!(id)
    :ok = Settings.destroy_service!(service, actor: socket.assigns.current_user)

    # Notify parent to reload services
    send(self(), {:saved_services, nil})

    services = Settings.list_services!()

    socket =
      socket
      |> assign(:services, services)
      |> assign_filtered_services(socket.assigns.search_query)

    {:noreply, put_flash(socket, :info, "service deleted successfully")}
  end

  @impl true
  def handle_event("show_add_modal", _, socket) do
    {:noreply, assign(socket, :show_modal, true)}
  end

  @impl true
  def handle_event("hide_modal", _, socket) do
    {:noreply, assign(socket, :show_modal, false)}
  end

  @impl true
  def handle_event("filter_services", params, socket) do
    query =
      params
      |> Map.get("query", "")
      |> String.trim()

    {:noreply, socket |> assign(:search_query, query) |> assign_filtered_services(query)}
  end

  defp new_service_form(user) do
    Services
    |> AshPhoenix.Form.for_create(:create,
      actor: user,
      as: "services"
    )
    |> to_form()
  end

  defp assign_filtered_services(socket, query) do
    assign(socket, :visible_services, filter_services(socket.assigns.services, query))
  end

  defp filter_services(services, ""), do: services

  defp filter_services(services, query) do
    downcased = String.downcase(query)

    Enum.filter(services, fn service ->
      service.name
      |> to_string()
      |> String.downcase()
      |> String.contains?(downcased)
    end)
  end
end
