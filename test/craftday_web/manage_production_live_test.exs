defmodule CraftdayWeb.ManageProductionLiveTest do
  use CraftdayWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  defp staff_user! do
    Craftday.DataCase.staff_actor()
  end

  defp sign_in(conn, user) do
    conn
    |> Plug.Test.put_req_cookie("timezone", "Etc/UTC")
    |> AshAuthentication.Phoenix.Plug.store_in_session(user)
    |> Plug.Conn.assign(:current_user, user)
  end

  test "renders production overview", %{conn: conn} do
    staff = staff_user!()
    conn = sign_in(conn, staff)

    {:ok, view, _html} = live(conn, ~p"/manage/production")
    assert has_element?(view, "#over-capacity-details")
    assert has_element?(view, "#material-shortages")
  end

  test "renders schedule tab", %{conn: conn} do
    staff = staff_user!()
    conn = sign_in(conn, staff)

    {:ok, view, _html} = live(conn, ~p"/manage/production/schedule")
    assert has_element?(view, "#controls")
  end

  test "renders make sheet and materials tabs", %{conn: conn} do
    staff = staff_user!()
    conn = sign_in(conn, staff)

    {:ok, view, _html} = live(conn, ~p"/manage/production/make_sheet")
    assert has_element?(view, "#make-sheet")

    {:ok, view, _html} = live(conn, ~p"/manage/production/materials")
    assert has_element?(view, "[role=tablist]")
  end
end
