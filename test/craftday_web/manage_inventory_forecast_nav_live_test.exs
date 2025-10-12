defmodule CraftdayWeb.ManageInventoryForecastNavLiveTest do
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

  test "inventory forecast controls update view", %{conn: conn} do
    conn = sign_in(conn, staff_user!())
    {:ok, view, _} = live(conn, ~p"/manage/inventory/forecast")

    assert has_element?(view, "#controls")
    initial = render(view)

    view
    |> element("button[phx-click=next_week]")
    |> render_click()

    after_next = render(view)
    refute after_next == initial

    view
    |> element("button[phx-click=today]")
    |> render_click()

    after_today = render(view)
    refute after_today == after_next
  end
end

