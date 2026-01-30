defmodule CraftplanWeb.PageControllerTest do
  use CraftplanWeb.ConnCase

  test "GET / redirects to /setup when no admin exists", %{conn: conn} do
    conn = get(conn, ~p"/")
    assert redirected_to(conn, 302) == "/setup"
  end

  test "GET / renders homepage when admin exists", %{conn: conn} do
    _admin = Craftplan.DataCase.admin_actor()

    conn = get(conn, ~p"/")
    body = html_response(conn, 200)
    assert body =~ "Craftplan"
    assert body =~ "Log in to workspace"
  end
end
