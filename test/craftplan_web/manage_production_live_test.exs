defmodule CraftplanWeb.ManageProductionLiveTest do
  use CraftplanWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  @tag role: :staff
  test "renders overview", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/manage/overview")
    assert has_element?(view, "#over-capacity-details")
    assert has_element?(view, "#material-shortages")
  end

  @tag role: :staff
  test "shows overview breadcrumb", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/manage/overview")
    html = render(view)
    assert html =~ "aria-label=\"Breadcrumb\""
    assert html =~ ">Overview<"
  end

  @tag role: :staff
  test "shows overview in manage nav", %{conn: conn} do
    {:ok, _view, html} = live(conn, ~p"/manage/overview")
    assert html =~ ~s(aria-label="Primary navigation")
    assert html =~ ">Overview<"
  end

  @tag role: :staff
  test "renders schedule tab", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/manage/production/schedule")
    assert has_element?(view, "#controls")
  end

  @tag role: :staff
  test "shows production breadcrumb on schedule", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/manage/production/schedule")
    html = render(view)
    assert html =~ "aria-label=\"Breadcrumb\""
    assert html =~ ">Production<"
  end

  @tag role: :staff
  test "shows production subnav on schedule", %{conn: conn} do
    {:ok, _view, html} = live(conn, ~p"/manage/production/schedule")
    assert html =~ ~s(role="tablist")
    assert html =~ ">Weekly<"
    assert html =~ ">Daily<"
  end

  @tag role: :staff
  test "renders make sheet and materials tabs", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/manage/production/make_sheet")
    assert has_element?(view, "#make-sheet")

    {:ok, view, _html} = live(conn, ~p"/manage/production/materials")
    assert has_element?(view, "[role=tablist]")
  end

  @tag role: :staff
  test "renders batches index", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/manage/production/batches")
    assert has_element?(view, "#batches-table")
  end
end
