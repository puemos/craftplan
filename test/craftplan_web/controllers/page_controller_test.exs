defmodule CraftplanWeb.PageControllerTest do
  use CraftplanWeb.ConnCase

  test "GET / renders homepage", %{conn: conn} do
    conn = get(conn, ~p"/")
    body = html_response(conn, 200)
    assert body =~ "Craftplan"
    assert body =~ "Focus on ovens"
    assert body =~ "Log in to workspace"
  end
end
