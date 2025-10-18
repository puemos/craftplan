defmodule CraftplanWeb.PageController do
  use CraftplanWeb, :controller

  def home(conn, _params) do
    # The home page is often custom made,
    # so skip the default app layout.
    conn = assign(conn, :current_path, "/")
    render(conn, :home, layout: false)
  end
end
