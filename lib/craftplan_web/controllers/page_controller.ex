defmodule CraftplanWeb.PageController do
  use CraftplanWeb, :controller

  require Ash.Query

  def home(conn, _params) do
    if conn.assigns[:current_user] do
      redirect(conn, to: ~p"/manage/production/schedule")
    else
      if admin_exists?() do
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
      else
        redirect(conn, to: ~p"/setup")
      end
    end
  end

  defp admin_exists? do
    Craftplan.Accounts.User
    |> Ash.Query.filter(role: :admin)
    |> Ash.read!(authorize?: false)
    |> Enum.any?()
  end
end
