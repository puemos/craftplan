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
