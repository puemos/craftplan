defmodule CraftdayWeb.ManageProductionScheduleInteractionsLiveTest do
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

  test "schedule view toggles and navigation", %{conn: conn} do
    conn = sign_in(conn, staff_user!())
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

