defmodule CraftplanWeb.LiveCommandPalette do
  @moduledoc """
  LiveView on_mount hook that handles navigation messages from the command palette.
  """
  import Phoenix.Component, only: [assign: 3]
  import Phoenix.LiveView, only: [attach_hook: 4, push_navigate: 2]

  def on_mount(:default, _params, _session, socket) do
    {:cont,
     socket
     |> assign(:command_palette_open, false)
     |> attach_hook(:command_palette_navigate, :handle_info, &handle_info/2)}
  end

  defp handle_info({:command_palette_navigate, path}, socket) do
    {:halt, push_navigate(socket, to: path)}
  end

  defp handle_info(_message, socket) do
    {:cont, socket}
  end
end
