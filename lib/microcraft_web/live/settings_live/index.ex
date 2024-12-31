defmodule MicrocraftWeb.SettingsLive.Index do
  @moduledoc false
  alias Microcraft.Settings
  use MicrocraftWeb, :live_view

  @impl true
  def render(assigns) do
    ~H"""
    <.header>
      <.breadcrumb>
        <:crumb label="Settings" path={~p"/backoffice/settings"} current?={true} />
      </.breadcrumb>
    </.header>

    <div class="max-w-lg">
      <.live_component
        module={MicrocraftWeb.SettingsLive.FormComponent}
        id="settings-form"
        current_user={@current_user}
        title={@page_title}
        action={@live_action}
        settings={@settings}
        patch={~p"/backoffice/settings"}
      />
    </div>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    settings = Settings.get_by_id!(socket.assigns.settings.id)

    {:ok,
     socket
     |> assign(:settings, settings)
     |> assign_new(:current_user, fn -> nil end)}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "Settings")
  end

  @impl true
  def handle_info({MicrocraftWeb.SettingsLive.FormComponent, {:saved, settings}}, socket) do
    {:noreply, assign(socket, :settings, settings)}
  end
end
