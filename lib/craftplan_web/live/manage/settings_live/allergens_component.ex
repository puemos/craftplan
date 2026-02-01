defmodule CraftplanWeb.SettingsLive.AllergensComponent do
  @moduledoc false
  use CraftplanWeb, :live_component

  alias Craftplan.Inventory
  alias Craftplan.Inventory.Allergen

  @impl true
  def render(assigns) do
    assigns = assign_new(assigns, :show_modal, fn -> false end)

    ~H"""
    <div class="space-y-6">
      <.header>
        <:subtitle>
          Search and manage the allergens available across your products and materials.
        </:subtitle>
        Allergens
      </.header>

      <div class="flex flex-col gap-6 lg:flex-row">
        <div class="flex-1">
          <div class="rounded-md border border-gray-200 bg-white">
            <div class="border-t border-stone-200 px-4 py-4">
              <form
                id="allergen-filter"
                phx-change="filter_allergens"
                phx-submit="filter_allergens"
                phx-target={@myself}
                class="space-y-4"
              >
                <label class="sr-only text-sm font-medium text-stone-700" for="allergen-filter-query">
                  Search allergens
                </label>
                <input
                  id="allergen-filter-query"
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
              <.table id="allergens" rows={@visible_allergens} wrapper_class="mt-0">
                <:col :let={allergen} label="Name">{allergen.name}</:col>
                <:action :let={allergen}>
                  <.link
                    phx-click={JS.push("delete", value: %{id: allergen.id}, target: @myself)}
                    data-confirm="Are you sure you want to delete this allergen? This action cannot be undone."
                  >
                    <.button size={:sm} variant={:danger}>
                      Delete
                    </.button>
                  </.link>
                </:action>
                <:empty>
                  <div class="py-6 text-center text-sm text-stone-500">
                    {if String.trim(@search_query) == "" do
                      "No allergens yet. Add your first allergen from the manage panel."
                    else
                      "No allergens match your search."
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
              Create new allergens or remove ones you no longer track. Changes apply immediately across Craftplan.
            </p>
            <.button
              type="button"
              variant={:primary}
              class="w-full justify-center"
              phx-click="show_add_modal"
              phx-target={@myself}
            >
              <.icon name="hero-plus" class="mr-2 h-4 w-4" /> Add Allergen
            </.button>
          </div>
        </aside>
      </div>

      <.modal
        :if={@show_modal}
        id="add-allergen-modal"
        show
        title="Add New Allergen"
        description="Enter the name of the allergen you want to add"
        on_cancel={JS.push("hide_modal", target: @myself)}
      >
        <.simple_form
          for={@form}
          id="allergen-form"
          phx-target={@myself}
          phx-change="validate"
          phx-submit="save"
        >
          <.input field={@form[:name]} type="text" label="Allergen name" />
          <:actions>
            <.button variant={:primary} phx-disable-with="Saving...">Save Allergen</.button>
          </:actions>
        </.simple_form>
      </.modal>
    </div>
    """
  end

  @impl true
  def update(assigns, socket) do
    allergens = Inventory.list_allergens!()
    form = new_allergen_form(assigns.current_user)
    search_query = Map.get(socket.assigns, :search_query, "")

    {:ok,
     socket
     |> assign(assigns)
     |> assign(:allergens, allergens)
     |> assign(:search_query, search_query)
     |> assign(:visible_allergens, filter_allergens(allergens, search_query))
     |> assign(:form, form)
     |> assign(:show_modal, false)}
  end

  @impl true
  def handle_event("validate", %{"allergen" => allergen_params}, socket) do
    form = AshPhoenix.Form.validate(socket.assigns.form, allergen_params)
    {:noreply, assign(socket, :form, form)}
  end

  @impl true
  def handle_event("save", %{"allergen" => allergen_params}, socket) do
    case AshPhoenix.Form.submit(socket.assigns.form, params: allergen_params) do
      {:ok, _allergen} ->
        # Notify parent to reload allergens
        send(self(), {:saved_allergens, nil})

        allergens = Inventory.list_allergens!()

        socket =
          socket
          |> assign(:form, new_allergen_form(socket.assigns.current_user))
          |> assign(:show_modal, false)
          |> assign(:allergens, allergens)
          |> assign_filtered_allergens(socket.assigns.search_query)

        {:noreply, put_flash(socket, :info, "Allergen added successfully")}

      {:error, form} ->
        {:noreply, assign(socket, :form, form)}
    end
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    allergen = Inventory.get_allergen_by_id!(id)
    :ok = Inventory.destroy_allergen!(allergen, actor: socket.assigns.current_user)

    # Notify parent to reload allergens
    send(self(), {:saved_allergens, nil})

    allergens = Inventory.list_allergens!()

    socket =
      socket
      |> assign(:allergens, allergens)
      |> assign_filtered_allergens(socket.assigns.search_query)

    {:noreply, put_flash(socket, :info, "Allergen deleted successfully")}
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
  def handle_event("filter_allergens", params, socket) do
    query =
      params
      |> Map.get("query", "")
      |> String.trim()

    {:noreply, socket |> assign(:search_query, query) |> assign_filtered_allergens(query)}
  end

  defp new_allergen_form(user) do
    Allergen
    |> AshPhoenix.Form.for_create(:create,
      actor: user,
      as: "allergen"
    )
    |> to_form()
  end

  defp assign_filtered_allergens(socket, query) do
    assign(socket, :visible_allergens, filter_allergens(socket.assigns.allergens, query))
  end

  defp filter_allergens(allergens, ""), do: allergens

  defp filter_allergens(allergens, query) do
    downcased = String.downcase(query)

    Enum.filter(allergens, fn allergen ->
      allergen.name
      |> to_string()
      |> String.downcase()
      |> String.contains?(downcased)
    end)
  end
end
