defmodule CraftplanWeb.PageController do
  use CraftplanWeb, :controller

  def home(conn, _params) do
    release_version =
      case Application.spec(:craftplan, :vsn) do
        nil -> "dev"
        version -> to_string(version)
      end

    conn
    |> assign(:current_path, "/")
    |> assign(:page_title, "Craftplan")
    |> put_layout(false)
    |> render(:home, release_version: release_version)
  end
end
