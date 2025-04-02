defmodule MicrocraftWeb.SettingsLive.Index do
  @moduledoc false
  use MicrocraftWeb, :live_view

  alias Microcraft.Inventory
  alias Microcraft.Settings

  @impl true
  def render(assigns) do
    ~H"""
    <.header>
      <.breadcrumb>
        <:crumb label="Settings" path={~p"/manage/settings"} current?={true} />
      </.breadcrumb>
    </.header>

    <.tabs id="settings-tabs">
      <:tab label="General" path={~p"/manage/settings?page=general"} selected?={@page == "general"}>
        <div class="max-w-lg">
          <.live_component
            module={MicrocraftWeb.SettingsLive.FormComponent}
            id="settings-form"
            current_user={@current_user}
            title={@page_title}
            action={@live_action}
            settings={@settings}
            patch={~p"/manage/settings?page=general"}
          />
        </div>
      </:tab>

      <:tab
        label="Allergens"
        path={~p"/manage/settings?page=allergens"}
        selected?={@page == "allergens"}
      >
        <div class="">
          <.live_component
            module={MicrocraftWeb.SettingsLive.AllergensComponent}
            id="allergens-component"
            current_user={@current_user}
            allergens={@allergens}
          />
        </div>
      </:tab>

      <:tab
        label="Nutritional Facts"
        path={~p"/manage/settings?page=nutritional_facts"}
        selected?={@page == "nutritional_facts"}
      >
        <div class="">
          <.live_component
            module={MicrocraftWeb.SettingsLive.NutritionalFactsComponent}
            id="nutritional-facts-component"
            current_user={@current_user}
            nutritional_facts={@nutritional_facts}
          />
        </div>
      </:tab>
    </.tabs>
    """
  end

  @impl true
  def mount(%{"page" => page}, _session, socket) do
    settings = Settings.get_by_id!(socket.assigns.settings.id)
    allergens = Inventory.list_allergens!()
    nutritional_facts = Inventory.list_nutritional_facts!()

    {:ok,
     socket
     |> assign(:settings, settings)
     |> assign(:allergens, allergens)
     |> assign(:nutritional_facts, nutritional_facts)
     |> assign(:page, page)
     |> assign_new(:current_user, fn -> nil end)}
  end

  @impl true
  def mount(_params, _session, socket) do
    # Default to general tab
    settings = Settings.get_by_id!(socket.assigns.settings.id)
    allergens = Inventory.list_allergens!()
    nutritional_facts = Inventory.list_nutritional_facts!()

    {:ok,
     socket
     |> assign(:settings, settings)
     |> assign(:allergens, allergens)
     |> assign(:nutritional_facts, nutritional_facts)
     |> assign(:page, "general")
     |> assign_new(:current_user, fn -> nil end)}
  end

  @impl true
  def handle_params(params, _url, socket) do
    page = Map.get(params, "page", "general")
    {:noreply, socket |> apply_action(socket.assigns.live_action, params) |> assign(:page, page)}
  end

  defp apply_action(socket, :index, _params) do
    assign(socket, :page_title, "Settings")
  end

  @impl true
  def handle_info({MicrocraftWeb.SettingsLive.FormComponent, {:saved, settings}}, socket) do
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
