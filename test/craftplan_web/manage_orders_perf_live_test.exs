defmodule CraftplanWeb.ManageOrdersPerfLiveTest do
  use CraftplanWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Craftplan.Test.Factory

  defp order_at(delivery_date, customer_name) do
    customer = Factory.create_customer!(%{first_name: customer_name, last_name: "Perf"})

    product =
      Factory.create_product!(%{name: "Perf Product #{System.unique_integer([:positive])}"})

    Factory.create_order_with_items!(
      customer,
      [%{product_id: product.id, quantity: 1, unit_price: product.price}],
      delivery_date: delivery_date
    )
  end

  defp days_from_now(days), do: DateTime.add(DateTime.utc_now(), days * 86_400, :second)

  describe "table pagination" do
    @tag role: :staff
    test "shows 100 of N and pages through the rest", %{conn: conn} do
      customer = Factory.create_customer!(%{first_name: "Page", last_name: "Tester"})
      product = Factory.create_product!()

      for _ <- 1..120 do
        Factory.create_order_with_items!(
          customer,
          [%{product_id: product.id, quantity: 1, unit_price: product.price}],
          delivery_date: DateTime.add(DateTime.utc_now(), 86_400, :second)
        )
      end

      {:ok, view, html} = live(conn, ~p"/manage/orders")
      assert html =~ "Showing 1-100 of 120"
      assert has_element?(view, "button[phx-click=next_page]:not([disabled])")

      next = view |> element("button[phx-click=next_page]") |> render_click()
      assert next =~ "Showing 101-120 of 120"
      assert has_element?(view, "button[phx-click=prev_page]:not([disabled])")

      prev = view |> element("button[phx-click=prev_page]") |> render_click()
      assert prev =~ "Showing 1-100 of 120"
    end
  end

  describe "calendar window scoping" do
    @tag role: :staff
    test "calendar_window/1 bounds the first..last day of the range in UTC" do
      range = [
        ~D[2026-06-22],
        ~D[2026-06-23],
        ~D[2026-06-24],
        ~D[2026-06-25],
        ~D[2026-06-26],
        ~D[2026-06-27],
        ~D[2026-06-28]
      ]

      {start_dt, end_dt} = CraftplanWeb.OrderLive.Index.calendar_window(range)

      assert start_dt == ~U[2026-06-22 00:00:00Z]
      assert end_dt == ~U[2026-06-28 23:59:59Z]
    end

    @tag role: :staff
    test "calendar shows this week's order and not next week's, and flips on navigation",
         %{conn: conn} do
      week_start = Date.add(Date.utc_today(), -(Date.day_of_week(Date.utc_today()) - 1))
      this_week = DateTime.new!(Date.add(week_start, 1), ~T[10:00:00], "Etc/UTC")
      next_week = DateTime.new!(Date.add(week_start, 8), ~T[10:00:00], "Etc/UTC")

      _c1 = order_at(this_week, "ThisWeekCust")
      _c2 = order_at(next_week, "NextWeekCust")

      {:ok, view, html} = live(conn, ~p"/manage/orders?view=calendar")
      assert html =~ "ThisWeekCust"
      refute html =~ "NextWeekCust"

      flipped = view |> element("button[phx-click=next_week]") |> render_click()
      assert flipped =~ "NextWeekCust"
      refute flipped =~ "ThisWeekCust"
    end
  end

  describe "count refresh on saved order" do
    @tag role: :staff
    test "creating an in-window order refreshes the count label", %{conn: conn} do
      customer = Factory.create_customer!(%{first_name: "Refresh", last_name: "Counts"})
      product = Factory.create_product!()

      _existing =
        Factory.create_order_with_items!(
          customer,
          [%{product_id: product.id, quantity: 1, unit_price: product.price}],
          delivery_date: DateTime.add(DateTime.utc_now(), 86_400, :second)
        )

      {:ok, view, html} = live(conn, ~p"/manage/orders")
      assert html =~ "of 1"

      send(
        view.pid,
        {CraftplanWeb.OrderLive.FormComponent,
         {:saved,
          Factory.create_order_with_items!(
            customer,
            [%{product_id: product.id, quantity: 1, unit_price: product.price}],
            delivery_date: DateTime.add(DateTime.utc_now(), 2 * 86_400, :second)
          )}}
      )

      assert render(view) =~ "of 2"
    end
  end

  describe "default delivery-date window" do
    @tag role: :staff
    test "pre-fills the date pickers with today-7 / today+90", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/manage/orders")
      today = Date.utc_today()
      assert html =~ Date.to_iso8601(Date.add(today, -7))
      assert html =~ Date.to_iso8601(Date.add(today, 90))
    end

    @tag role: :staff
    test "excludes orders outside the window, includes them after clearing dates", %{conn: conn} do
      _in_window = order_at(days_from_now(1), "InWindow")
      _out_of_window = order_at(days_from_now(-60), "WayBack")

      {:ok, view, html} = live(conn, ~p"/manage/orders")
      assert html =~ "InWindow"
      refute html =~ "WayBack"

      cleared =
        view
        |> element("#filters-form")
        |> render_change(%{
          "filters" => %{"delivery_date_start" => "", "delivery_date_end" => ""}
        })

      assert cleared =~ "WayBack"
    end
  end
end
