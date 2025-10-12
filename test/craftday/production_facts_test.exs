defmodule Craftday.ProductionFactsTest do
  use Craftday.DataCase, async: true

  alias Craftday.Catalog
  alias Craftday.CRM
  alias Craftday.Orders
  alias Craftday.Production

  test "quantities_by_product_day and orders_count_by_day produce expected facts" do
    staff = Craftday.DataCase.staff_actor()

    {:ok, c} =
      CRM.Customer
      |> Ash.Changeset.for_create(:create, %{
        type: :individual,
        first_name: "A",
        last_name: "B",
        email: "a@b.c"
      })
      |> Ash.create()

    {:ok, p} =
      Catalog.Product
      |> Ash.Changeset.for_create(:create, %{
        name: "Prod",
        status: :active,
        price: Decimal.new("9.00"),
        sku: "PR-1",
        max_daily_quantity: 4
      })
      |> Ash.create(actor: staff)

    d1 = Date.utc_today()
    d2 = Date.add(d1, 1)
    tz = "Etc/UTC"
    dt1 = DateTime.new!(d1, ~T[09:00:00], tz)
    dt2 = DateTime.new!(d2, ~T[09:00:00], tz)

    # Day 1: two orders 1x and 2x => qty 3
    {:ok, _} =
      Orders.Order
      |> Ash.Changeset.for_create(:create, %{
        customer_id: c.id,
        delivery_date: dt1,
        items: [%{product_id: p.id, quantity: Decimal.new(1), unit_price: p.price}]
      })
      |> Ash.create(actor: staff)

    {:ok, _} =
      Orders.Order
      |> Ash.Changeset.for_create(:create, %{
        customer_id: c.id,
        delivery_date: dt1,
        items: [%{product_id: p.id, quantity: Decimal.new(2), unit_price: p.price}]
      })
      |> Ash.create(actor: staff)

    # Day 2: one order 1x => qty 1
    {:ok, _} =
      Orders.Order
      |> Ash.Changeset.for_create(:create, %{
        customer_id: c.id,
        delivery_date: dt2,
        items: [%{product_id: p.id, quantity: Decimal.new(1), unit_price: p.price}]
      })
      |> Ash.create(actor: staff)

    range = [d1, d2]
    orders = Production.fetch_orders_in_range(tz, range, actor: staff)
    prod_items = Production.build_production_items(orders)

    qty_rows = Production.quantities_by_product_day(range, prod_items)
    assert Enum.any?(qty_rows, &(&1.day == d1 and Decimal.equal?(&1.qty, Decimal.new(3))))
    assert Enum.any?(qty_rows, &(&1.day == d2 and Decimal.equal?(&1.qty, Decimal.new(1))))

    counts = Production.orders_count_by_day(range, orders)
    assert Enum.find(counts, &(&1.day == d1)).count == 2
    assert Enum.find(counts, &(&1.day == d2)).count == 1
  end
end
