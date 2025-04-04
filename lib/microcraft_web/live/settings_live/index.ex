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
      <:tab
        label="General"
        path={~p"/manage/settings/general"}
        selected?={@live_action == :general || @live_action == :index}
      >
        <div class="max-w-lg">
          <.live_component
            module={MicrocraftWeb.SettingsLive.FormComponent}
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
            module={MicrocraftWeb.SettingsLive.AllergensComponent}
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
  def mount(_params, _session, socket) do
    settings = Settings.get_by_id!(socket.assigns.settings.id)
    allergens = Inventory.list_allergens!()
    nutritional_facts = Inventory.list_nutritional_facts!()

    {:ok,
     socket
     |> assign(:settings, settings)
     |> assign(:allergens, allergens)
     |> assign(:nutritional_facts, nutritional_facts)
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
