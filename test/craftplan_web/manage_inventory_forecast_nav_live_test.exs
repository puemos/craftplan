defmodule CraftplanWeb.ManageInventoryForecastNavLiveTest do
  use CraftplanWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  @tag role: :staff
  test "inventory forecast controls update view", %{conn: conn} do
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
