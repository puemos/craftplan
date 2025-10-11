defmodule CraftdayWeb.PageControllerTest do
  use CraftdayWeb.ConnCase

  test "GET / renders homepage", %{conn: conn} do
    conn = get(conn, ~p"/")
    body = html_response(conn, 200)
    assert body =~ "Craftday"
    assert body =~ "Crafting excellence"
  end
end
