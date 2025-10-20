defmodule CraftplanWeb.LiveNav do
  @moduledoc false
  import Phoenix.Component, only: [assign: 3]
  import Phoenix.LiveView, only: [attach_hook: 4]

  def on_mount(:default, _params, _session, socket) do
    if socket.router == nil do
      {:cont, assign(socket, :nav_section, nil)}
    else
      {:cont, attach_hook(socket, :assign_nav_section, :handle_params, &assign_nav_section/3)}
    end
  end

  defp assign_nav_section(_params, url, socket) do
    path = URI.parse(url).path || ""
    base_path = socket.assigns[:organization_base_path] || ""
    scoped_path = String.replace_prefix(path, base_path, "")

    section =
      cond do
        String.starts_with?(scoped_path, "/manage/production") -> :production
        String.starts_with?(scoped_path, "/manage/inventory") -> :inventory
        String.starts_with?(scoped_path, "/manage/purchasing") -> :purchasing
        String.starts_with?(scoped_path, "/manage/products") -> :products
        String.starts_with?(scoped_path, "/manage/orders") -> :orders
        String.starts_with?(scoped_path, "/manage/customers") -> :customers
        String.starts_with?(scoped_path, "/manage/settings") -> :settings
        true -> nil
      end

    {:cont, assign(socket, :nav_section, section)}
  end
end
