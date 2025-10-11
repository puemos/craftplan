defmodule CraftdayWeb.ManageRoutesExistTest do
  use CraftdayWeb.ConnCase, async: true

  test "/manage/production exists and requires auth", %{conn: conn} do
    conn = get(conn, ~p"/manage/production")
    assert redirected_to(conn, 302) =~ "/sign-in"
  end

  test "/manage/purchasing exists and requires auth", %{conn: conn} do
    conn = get(conn, ~p"/manage/purchasing")
    assert redirected_to(conn, 302) =~ "/sign-in"
  end

  test "/manage/purchasing/suppliers exists and requires auth", %{conn: conn} do
    conn = get(conn, ~p"/manage/purchasing/suppliers")
    assert redirected_to(conn, 302) =~ "/sign-in"
  end

  test "/manage/purchasing/:po_ref exists and requires auth", %{conn: conn} do
    conn = get(conn, "/manage/purchasing/PO_XXXX_XX_XX_ABCDEF")
    assert redirected_to(conn, 302) =~ "/sign-in"
  end
end
