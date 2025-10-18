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

    <.tabs id="settings-tabs">
      <:tab
        label="General"
        path={~p"/manage/settings/general"}
        selected?={@live_action == :general || @live_action == :index}
      >
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
      </:tab>

      <:tab
        label="Allergens"
        path={~p"/manage/settings/allergens"}
        selected?={@live_action == :allergens}
      >
        <div class="">
          <.live_component
            module={CraftplanWeb.SettingsLive.AllergensComponent}
            id="allergens-component"
            current_user={@current_user}
            allergens={@allergens}
          />
        </div>
      </:tab>

      <:tab
        label="Nutritional Facts"
        path={~p"/manage/settings/nutritional_facts"}
        selected?={@live_action == :nutritional_facts}
      >
        <div class="">
          <.live_component
            module={CraftplanWeb.SettingsLive.NutritionalFactsComponent}
            id="nutritional-facts-component"
            current_user={@current_user}
            nutritional_facts={@nutritional_facts}
          />
        </div>
      </:tab>

      <:tab
        label="CSV"
        path={~p"/manage/settings/csv"}
        selected?={@live_action == :csv}
      >
        <div class="max-w-2xl">
          <h2 class="mb-4 text-lg font-medium">CSV Import</h2>
          <.form for={@csv_form} id="csv-import-form" phx-submit="csv_import">
            <div class="grid grid-cols-1 gap-4 sm:grid-cols-2">
              <.input
                type="select"
                name="entity"
                label="Entity"
                options={[
                  {"Products", "products"},
                  {"Materials", "materials"},
                  {"Customers", "customers"}
                ]}
                value="products"
                required
              />
              <.input type="text" name="delimiter" label="Delimiter" value="," />
              <.input type="checkbox" name="dry_run" label="Dry run" checked />
              <div>
                <label class="mb-1 block text-sm font-medium text-stone-700">CSV File</label>
                <input type="file" name="csv" class="block w-full text-sm" />
              </div>
            </div>
            <div class="mt-6 flex gap-2">
              <.button id="csv-import-submit">Import</.button>
              <.button variant={:outline} id="csv-template-download" type="button">
                Download Template
              </.button>
            </div>
          </.form>

          <h2 class="mt-8 mb-4 text-lg font-medium">CSV Export</h2>
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
              <.button id="csv-export-submit">Export</.button>
            </div>
          </.form>
        </div>
      </:tab>
    </.tabs>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    settings = Settings.get_by_id!(socket.assigns.settings.id)
    allergens = Inventory.list_allergens!()
    nutritional_facts = Inventory.list_nutritional_facts!()

    {:ok,
     socket
     |> assign(:settings, settings)
     |> assign(:allergens, allergens)
     |> assign(:nutritional_facts, nutritional_facts)
     |> assign(:csv_form, to_form(%{}))
     |> assign(:csv_export_form, to_form(%{}))
     |> assign_new(:current_user, fn -> nil end)}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
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
    assign(socket, :page_title, "CSV Import/Export")
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
