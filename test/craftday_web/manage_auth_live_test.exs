defmodule CraftdayWeb.ManageAuthLiveTest do
  use CraftdayWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  test "manage products redirects unauthenticated to sign-in", %{conn: conn} do
    assert {:error, {:redirect, %{to: "/sign-in"}}} = live(conn, ~p"/manage/products")
  end
end
