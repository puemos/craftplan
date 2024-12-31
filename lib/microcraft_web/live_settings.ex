defmodule MicrocraftWeb.LiveSettings do
  @moduledoc """
  Helpers for authenticating users in LiveViews.
  """

  import Phoenix.Component
  use MicrocraftWeb, :verified_routes

  def on_mount(:default, _params, _session, socket) do
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

      socket = assign(socket, :settings, settings)
      {:cont, socket}
    end
  end
end
