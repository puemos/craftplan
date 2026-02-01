defmodule CraftplanWeb.SettingsLive.NutritionalFactsComponent do
  @moduledoc false
  use CraftplanWeb, :live_component

  alias Craftplan.Inventory
  alias Craftplan.Inventory.NutritionalFact

  @impl true
  def render(assigns) do
    assigns = assign_new(assigns, :show_modal, fn -> false end)

    ~H"""
    <div class="space-y-6">
      <.header>
        <:subtitle>Keep a central list of nutrients you add to recipes and packaging.</:subtitle>
        Nutritional Facts
      </.header>

      <div class="flex flex-col gap-6 lg:flex-row">
        <div class="flex-1">
          <div class="rounded-md border border-gray-200 bg-white">
            <div class="border-t border-stone-200 px-4 py-4">
              <form
                id="nutritional-fact-filter"
                phx-change="filter_facts"
                phx-submit="filter_facts"
                phx-target={@myself}
                class="space-y-2"
              >
                <label
                  class="sr-only text-sm font-medium text-stone-700"
                  for="nutritional-fact-filter-query"
                >
                  Search nutritional facts
                </label>
                <input
                  id="nutritional-fact-filter-query"
                  name="query"
                  type="search"
                  value={@search_query}
                  placeholder="Filter by name..."
                  phx-debounce="300"
                  class="w-full rounded-md border border-stone-300 bg-white px-3 py-2 text-sm text-stone-900 transition focus:border-primary-400 focus:ring-primary-200/60 focus:outline-none focus:ring"
                />
              </form>
            </div>

            <div class="-mt-10 p-4">
              <.table
                id="nutritional-facts"
                rows={@visible_facts}
                wrapper_class="mt-0"
              >
                <:col :let={fact} label="Name">{fact.name}</:col>
                <:action :let={fact}>
                  <.link
                    phx-click={JS.push("delete", value: %{id: fact.id}, target: @myself)}
                    data-confirm="Are you sure you want to delete this nutritional fact? This action cannot be undone."
                  >
                    <.button size={:sm} variant={:danger}>
                      Delete
                    </.button>
                  </.link>
                </:action>
                <:empty>
                  <div class="py-6 text-center text-sm text-stone-500">
                    {if String.trim(@search_query) == "" do
                      "No nutritional facts yet. Add your first entry from the manage panel."
                    else
                      "No nutritional facts match your search."
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
              Add nutritional facts that you frequently reference. These appear anywhere you select nutrients.
            </p>
            <.button
              type="button"
              variant={:primary}
              class="w-full justify-center"
              phx-click="show_modal"
              phx-target={@myself}
            >
              <.icon name="hero-plus" class="mr-2 h-4 w-4" /> Add Nutritional Fact
            </.button>
          </div>
        </aside>
      </div>

      <.modal
        :if={@show_modal}
        id="add-nutritional-fact-modal"
        show
        title="Add Nutritional Fact"
        description="Enter the name of the nutritional fact you want to add"
        on_cancel={JS.push("hide_modal", target: @myself)}
      >
        <.simple_form
          for={@form}
          id="nutritional-fact-form"
          phx-target={@myself}
          phx-change="validate"
          phx-submit="save"
        >
          <.input field={@form[:name]} type="text" label="Nutritional fact name" />
          <:actions>
            <.button variant={:primary} phx-disable-with="Saving...">Add Nutritional Fact</.button>
          </:actions>
        </.simple_form>
      </.modal>
    </div>
    """
  end

  @impl true
  def update(assigns, socket) do
    nutritional_facts = Inventory.list_nutritional_facts!()
    form = new_nutritional_fact_form(assigns.current_user)
    search_query = Map.get(socket.assigns, :search_query, "")

    {:ok,
     socket
     |> assign(assigns)
     |> assign(:nutritional_facts, nutritional_facts)
     |> assign(:search_query, search_query)
     |> assign(:visible_facts, filter_facts(nutritional_facts, search_query))
     |> assign(:form, form)
     |> assign(:show_modal, false)}
  end

  @impl true
  def handle_event("validate", %{"nutritional_fact" => fact_params}, socket) do
    form = AshPhoenix.Form.validate(socket.assigns.form, fact_params)
    {:noreply, assign(socket, :form, form)}
  end

  @impl true
  def handle_event("save", %{"nutritional_fact" => fact_params}, socket) do
    case AshPhoenix.Form.submit(socket.assigns.form, params: fact_params) do
      {:ok, _nutritional_fact} ->
        # Notify parent to reload nutritional facts
        send(self(), {:saved_nutritional_facts, nil})

        nutritional_facts = Inventory.list_nutritional_facts!()

        socket =
          socket
          |> assign(:form, new_nutritional_fact_form(socket.assigns.current_user))
          |> assign(:show_modal, false)
          |> assign(:nutritional_facts, nutritional_facts)
          |> assign_filtered_facts(socket.assigns.search_query)

        {:noreply, put_flash(socket, :info, "Nutritional fact added successfully")}

      {:error, form} ->
        {:noreply, assign(socket, :form, form)}
    end
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    nutritional_fact = Inventory.get_nutritional_fact_by_id!(id)

    :ok =
      Inventory.destroy_nutritional_fact!(nutritional_fact, actor: socket.assigns.current_user)

    # Notify parent to reload nutritional facts
    send(self(), {:saved_nutritional_facts, nil})

    nutritional_facts = Inventory.list_nutritional_facts!()

    socket =
      socket
      |> assign(:nutritional_facts, nutritional_facts)
      |> assign_filtered_facts(socket.assigns.search_query)

    {:noreply, put_flash(socket, :info, "Nutritional fact deleted successfully")}
  end

  @impl true
  def handle_event("show_modal", _, socket) do
    {:noreply, assign(socket, :show_modal, true)}
  end

  @impl true
  def handle_event("hide_modal", _, socket) do
    {:noreply, assign(socket, :show_modal, false)}
  end

  @impl true
  def handle_event("filter_facts", params, socket) do
    query =
      params
      |> Map.get("query", "")
      |> String.trim()

    {:noreply, socket |> assign(:search_query, query) |> assign_filtered_facts(query)}
  end

  defp new_nutritional_fact_form(user) do
    NutritionalFact
    |> AshPhoenix.Form.for_create(:create,
      actor: user,
      as: "nutritional_fact"
    )
    |> to_form()
  end

  defp assign_filtered_facts(socket, query) do
    assign(socket, :visible_facts, filter_facts(socket.assigns.nutritional_facts, query))
  end

  defp filter_facts(nutritional_facts, ""), do: nutritional_facts

  defp filter_facts(nutritional_facts, query) do
    downcased = String.downcase(query)

    Enum.filter(nutritional_facts, fn fact ->
      fact.name
      |> to_string()
      |> String.downcase()
      |> String.contains?(downcased)
    end)
  end
end
