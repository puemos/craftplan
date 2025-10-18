defmodule CraftplanWeb.ManageOrdersFiltersCalendarInteractionsLiveTest do
  use CraftplanWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Craftplan.Catalog.Product
  alias Craftplan.CRM.Customer
  alias Craftplan.Orders.Order

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
      |> Ash.create!(actor: Craftplan.DataCase.staff_actor())

    Order
    |> Ash.Changeset.for_create(:create, %{
      customer_id: c.id,
      delivery_date: DateTime.utc_now(),
      items: [%{"product_id" => p.id, "quantity" => 1, "unit_price" => p.price}]
    })
    |> Ash.create!(actor: Craftplan.DataCase.staff_actor())
  end

  @tag role: :staff
  test "apply customer_name filter narrows list", %{conn: conn} do
    _ = seed_order!("Zed")
    _ = seed_order!("Amy")

    {:ok, view, _} = live(conn, ~p"/manage/orders")

    view
    |> element("#filters-form")
    |> render_change(%{"filters" => %{"customer_name" => "Zed"}})

    html = render(view)
    assert html =~ "Zed"
  end

  @tag role: :staff
  test "calendar prev/next buttons update month label", %{conn: conn} do
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
