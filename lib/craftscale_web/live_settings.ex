defmodule CraftScaleWeb.LiveSettings do
  @moduledoc """
  Helpers for authenticating users in LiveViews.
  """

  use CraftScaleWeb, :verified_routes

  import Phoenix.Component

  def on_mount(:default, _params, _session, socket) do
    if socket.assigns[:settings] do
      {:cont, socket}
    else
      settings =
        case CraftScale.Settings.get() do
          {:ok, settings} ->
            settings

          {:error, _error} ->
            CraftScale.Settings.init!()
        end

      socket = assign(socket, :settings, settings)
      {:cont, socket}
    end
  end
end
