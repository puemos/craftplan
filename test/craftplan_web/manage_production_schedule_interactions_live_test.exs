defmodule CraftplanWeb.ManageProductionScheduleInteractionsLiveTest do
  use CraftplanWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  @tag role: :staff
  test "schedule view toggles and navigation", %{conn: conn} do
    {:ok, view, _} = live(conn, ~p"/manage/production/schedule")

    initial = render(view)

    # Toggle to week view
    view
    |> element("button[phx-click=set_schedule_view][phx-value-view=week]")
    |> render_click()

    week = render(view)
    refute week == initial

    # Navigate next week
    view
    |> element("button[phx-click=next_week]")
    |> render_click()

    after_next = render(view)
    refute after_next == week

    # Today button
    view
    |> element("button[phx-click=today]")
    |> render_click()

    after_today = render(view)
    refute after_today == after_next
  end
end
