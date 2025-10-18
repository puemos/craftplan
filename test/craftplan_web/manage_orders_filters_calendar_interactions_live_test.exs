defmodule CraftplanWeb.ManageOrdersFiltersCalendarInteractionsLiveTest do
  use CraftplanWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Craftplan.Catalog.Product
  alias Craftplan.CRM.Customer
  alias Craftplan.Orders.Order

  defp staff_user! do
    Craftplan.DataCase.staff_actor()
  end

  defp sign_in(conn, user) do
    conn
    |> Plug.Test.put_req_cookie("timezone", "Etc/UTC")
    |> AshAuthentication.Phoenix.Plug.store_in_session(user)
    |> Plug.Conn.assign(:current_user, user)
  end

  defp seed_order!(customer_name) do
    c =
      Customer
      |> Ash.Changeset.for_create(:create, %{
        type: :individual,
        first_name: customer_name,
        last_name: "Test"
      })
      |> Ash.create!()

    p =
      Product
      |> Ash.Changeset.for_create(:create, %{
        name: "P-#{System.unique_integer()}",
        sku: "SKU-#{System.unique_integer()}",
        price: Decimal.new("3.50"),
        status: :active
      })
      |> Ash.create!(actor: staff_user!())

    Order
    |> Ash.Changeset.for_create(:create, %{
      customer_id: c.id,
      delivery_date: DateTime.utc_now(),
      items: [%{"product_id" => p.id, "quantity" => 1, "unit_price" => p.price}]
    })
    |> Ash.create!(actor: staff_user!())
  end

  test "apply customer_name filter narrows list", %{conn: conn} do
    _ = seed_order!("Zed")
    _ = seed_order!("Amy")
    conn = sign_in(conn, staff_user!())

    {:ok, view, _} = live(conn, ~p"/manage/orders")

    view
    |> element("#filters-form")
    |> render_change(%{"filters" => %{"customer_name" => "Zed"}})

    html = render(view)
    assert html =~ "Zed"
  end

  test "calendar prev/next buttons update month label", %{conn: conn} do
    conn = sign_in(conn, staff_user!())
    {:ok, view, _} = live(conn, ~p"/manage/orders?view=calendar")

    initial = render(view)

    view
    |> element("button[phx-click=next_week]")
    |> render_click()

    next = render(view)
    refute next == initial

    view
    |> element("button[phx-click=prev_week]")
    |> render_click()

    prev = render(view)
    refute prev == next
  end
end
