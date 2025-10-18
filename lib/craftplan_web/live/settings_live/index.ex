defmodule CraftplanWeb.SettingsLive.Index do
  @moduledoc false
  use CraftplanWeb, :live_view

  alias Craftplan.Inventory
  alias Craftplan.Settings

  @impl true
  def render(assigns) do
    ~H"""
    <.header>
      <.breadcrumb>
        <:crumb label="Settings" path={~p"/manage/settings"} current?={true} />
      </.breadcrumb>
    </.header>

    <div class="mt-4 space-y-6">
      <div :if={@live_action in [:general, :index]}>
        <div class="max-w-lg">
          <.live_component
            module={CraftplanWeb.SettingsLive.FormComponent}
            id="settings-form"
            current_user={@current_user}
            title={@page_title}
            action={@live_action}
            settings={@settings}
            patch={~p"/manage/settings/general"}
          />
        </div>
      </div>

      <div :if={@live_action == :allergens}>
        <div class="">
          <.live_component
            module={CraftplanWeb.SettingsLive.AllergensComponent}
            id="allergens-component"
            current_user={@current_user}
            allergens={@allergens}
          />
        </div>
      </div>

      <div :if={@live_action == :nutritional_facts}>
        <div class="">
          <.live_component
            module={CraftplanWeb.SettingsLive.NutritionalFactsComponent}
            id="nutritional-facts-component"
            current_user={@current_user}
            nutritional_facts={@nutritional_facts}
          />
        </div>
      </div>

      <div :if={@live_action == :csv}>
        <div class="max-w-2xl">
          <h2 class="mb-2 text-lg font-medium">Import & Export</h2>
          <p class="mb-4 text-sm text-stone-700">Click on the entity you wish to import.</p>
          <div class="mb-8 flex gap-3">
            <.button variant={:outline} phx-click="open_import" phx-value-entity="products">
              <.icon name="hero-cube-solid" class="h-4 w-4" /> Products
            </.button>
            <.button variant={:outline} phx-click="open_import" phx-value-entity="materials">
              <.icon name="hero-archive-box-solid" class="h-4 w-4" /> Materials
            </.button>
            <.button variant={:outline} phx-click="open_import" phx-value-entity="customers">
              <.icon name="hero-user-group-solid" class="h-4 w-4" /> Customers
            </.button>
          </div>

          <h2 class="mt-10 mb-4 text-lg font-medium">Export</h2>
          <.form for={@csv_export_form} id="csv-export-form" phx-submit="csv_export">
            <div class="grid grid-cols-1 gap-4 sm:grid-cols-2">
              <.input
                type="select"
                name="entity"
                label="Entity"
                options={[
                  {"Orders", "orders"},
                  {"Customers", "customers"},
                  {"Inventory Movements", "movements"}
                ]}
                value="orders"
                required
              />
            </div>
            <div class="mt-6 flex gap-2">
              <.button id="csv-export-submit" variant={:primary}>Export</.button>
            </div>
          </.form>
          <.live_component
            module={CraftplanWeb.ImportModalComponent}
            id="csv-mapping-modal"
            show={@show_mapping_modal}
            entity={@selected_entity}
            current_user={@current_user}
          />
        </div>
      </div>
    </div>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    settings = Settings.get_by_id!(socket.assigns.settings.id)
    allergens = Inventory.list_allergens!()
    nutritional_facts = Inventory.list_nutritional_facts!()

    socket =
      socket
      |> assign(:settings, settings)
      |> assign(:allergens, allergens)
      |> assign(:nutritional_facts, nutritional_facts)
      |> assign(:csv_form, to_form(%{}))
      |> assign(:csv_export_form, to_form(%{}))
      |> assign(:show_mapping_modal, false)
      |> assign(:selected_entity, nil)
      |> assign_new(:current_user, fn -> nil end)

    # Always configure CSV upload; harmless on other tabs and avoids missing @uploads
    socket =
      allow_upload(socket, :csv,
        accept: [".csv", "text/csv"],
        max_entries: 1
      )

    {:ok, socket}
  end

  @impl true
  def handle_params(params, _url, socket) do
    live_action = socket.assigns.live_action

    nav_sub_links = settings_sub_links(live_action)

    socket =
      socket
      |> assign(:nav_sub_links, nav_sub_links)
      |> apply_action(live_action, params)

    {:noreply, socket}
  end

  @impl true
  def handle_event("open_import", %{"entity" => entity}, socket) do
    {:noreply,
     socket
     |> assign(:selected_entity, entity)
     |> assign(:show_mapping_modal, true)}
  end

  defp apply_action(socket, :index, _params) do
    assign(socket, :page_title, "Settings")
  end

  defp apply_action(socket, :general, _params) do
    assign(socket, :page_title, "General Settings")
  end

  defp apply_action(socket, :allergens, _params) do
    assign(socket, :page_title, "Allergens Settings")
  end

  defp apply_action(socket, :nutritional_facts, _params) do
    assign(socket, :page_title, "Nutritional Facts Settings")
  end

  defp apply_action(socket, :csv, _params) do
    assign(socket, :page_title, "Import & Export")
  end

  defp settings_sub_links(live_action) do
    [
      %{
        label: "General",
        navigate: ~p"/manage/settings/general",
        active: live_action in [:general, :index]
      },
      %{
        label: "Allergens",
        navigate: ~p"/manage/settings/allergens",
        active: live_action == :allergens
      },
      %{
        label: "Nutritional Facts",
        navigate: ~p"/manage/settings/nutritional_facts",
        active: live_action == :nutritional_facts
      },
      %{
        label: "Import & Export",
        navigate: ~p"/manage/settings/csv",
        active: live_action == :csv
      }
    ]
  end

  def handle_event("csv_export", _params, socket) do
    {:noreply, put_flash(socket, :info, "Export started (not yet implemented)")}
  end

  # Component close callback from ImportModalComponent
  @impl true
  def handle_info({:import_modal, :closed}, socket) do
    {:noreply, assign(socket, :show_mapping_modal, false)}
  end

  @impl true
  def handle_info({CraftplanWeb.SettingsLive.FormComponent, {:saved, settings}}, socket) do
    {:noreply, assign(socket, :settings, settings)}
  end

  @impl true
  def handle_info({:saved_allergens, _id}, socket) do
    allergens = Inventory.list_allergens!()
    {:noreply, assign(socket, :allergens, allergens)}
  end

  @impl true
  def handle_info({:saved_nutritional_facts, _id}, socket) do
    nutritional_facts = Inventory.list_nutritional_facts!()
    {:noreply, assign(socket, :nutritional_facts, nutritional_facts)}
  end
end
