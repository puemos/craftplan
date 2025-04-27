defmodule CraftdayWeb.LiveCurrentPath do
  @moduledoc false
  import Phoenix.Component, only: [assign: 3]
  import Phoenix.LiveView, only: [attach_hook: 4]

  def on_mount(:default, _params, _session, socket) do
    if socket.router == nil do
      {:cont, assign(socket, :current_path, "")}
    else
      {:cont, attach_hook(socket, :assign_current_path, :handle_params, &assign_current_path/3)}
    end
  end

  defp assign_current_path(_params, url, socket) do
    uri = url |> URI.parse() |> current_path()

    {:cont, assign(socket, :current_path, uri)}
  end

  defp current_path(%URI{} = uri) when is_binary(uri.path) and is_binary(uri.query) do
    uri.path <> "?" <> uri.query
  end

  defp current_path(%URI{:path => path}), do: path
end
