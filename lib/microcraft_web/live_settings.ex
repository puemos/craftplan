defmodule MicrocraftWeb.LiveSettings do
  @moduledoc """
  Helpers for authenticating users in LiveViews.
  """

  use MicrocraftWeb, :verified_routes

  import Phoenix.Component

  def on_mount(:default, _params, _session, socket) do
    time_zone = Phoenix.LiveView.get_connect_params(socket)["timezone"]

    if socket.assigns[:settings] do
      {:cont, socket}
    else
      settings =
        case Microcraft.Settings.get() do
          {:ok, settings} ->
            settings

          {:error, _error} ->
            Microcraft.Settings.init!()
        end

      socket =
        socket
        |> assign(:settings, settings)
        |> assign(:time_zone, time_zone)

      {:cont, socket}
    end
  end
end
