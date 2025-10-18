defmodule CraftplanWeb.ManageProductionLiveTest do
  use CraftplanWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  @tag role: :staff
  test "renders production overview", %{conn: conn} do

    {:ok, view, _html} = live(conn, ~p"/manage/production")
    assert has_element?(view, "#over-capacity-details")
    assert has_element?(view, "#material-shortages")
  end

  @tag role: :staff
  test "renders schedule tab", %{conn: conn} do

    {:ok, view, _html} = live(conn, ~p"/manage/production/schedule")
    assert has_element?(view, "#controls")
  end

  @tag role: :staff
  test "renders make sheet and materials tabs", %{conn: conn} do

    {:ok, view, _html} = live(conn, ~p"/manage/production/make_sheet")
    assert has_element?(view, "#make-sheet")

    {:ok, view, _html} = live(conn, ~p"/manage/production/materials")
    assert has_element?(view, "[role=tablist]")
  end
end
