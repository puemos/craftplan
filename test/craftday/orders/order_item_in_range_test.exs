defmodule Craftday.Orders.OrderItemInRangeTest do
  use Craftday.DataCase, async: true

  alias Craftday.Catalog
  alias Craftday.CRM
  alias Craftday.Orders
  alias Craftday.Orders.OrderItem

  test "read :in_range filters by date and product" do
    {:ok, customer} =
      CRM.Customer
      |> Ash.Changeset.for_create(:create, %{
        type: :individual,
        first_name: "Al",
        last_name: "Ice",
        email: "al.ice@example.com"
      })
      |> Ash.create()

    staff = Craftday.DataCase.staff_actor()

    {:ok, p1} =
      Catalog.Product
      |> Ash.Changeset.for_create(:create, %{
        name: "P1",
        status: :active,
        price: Decimal.new("5.00"),
        sku: "P-1"
      })
      |> Ash.create(actor: staff)

    {:ok, p2} =
      Catalog.Product
      |> Ash.Changeset.for_create(:create, %{
        name: "P2",
        status: :active,
        price: Decimal.new("7.00"),
        sku: "P-2"
      })
      |> Ash.create(actor: staff)

    d1 = Date.utc_today()
    d2 = Date.add(d1, 1)
    dt1 = DateTime.new!(d1, ~T[10:00:00], "Etc/UTC")
    dt2 = DateTime.new!(d2, ~T[10:00:00], "Etc/UTC")

    {:ok, _o1} =
      Orders.Order
      |> Ash.Changeset.for_create(:create, %{
        customer_id: customer.id,
        delivery_date: dt1,
        items: [
          %{product_id: p1.id, quantity: Decimal.new(2), unit_price: p1.price},
          %{product_id: p2.id, quantity: Decimal.new(1), unit_price: p2.price}
        ]
      })
      |> Ash.create(actor: staff)

    {:ok, _o2} =
      Orders.Order
      |> Ash.Changeset.for_create(:create, %{
        customer_id: customer.id,
        delivery_date: dt2,
        items: [
          %{product_id: p1.id, quantity: Decimal.new(3), unit_price: p1.price}
        ]
      })
      |> Ash.create(actor: staff)

    start_dt1 = DateTime.new!(d1, ~T[00:00:00], "Etc/UTC")
    end_dt1 = DateTime.new!(d1, ~T[23:59:59], "Etc/UTC")

    items_d1 =
      OrderItem
      |> Ash.Query.for_read(:in_range, %{start_date: start_dt1, end_date: end_dt1})
      |> Ash.read!()

    assert length(items_d1) == 2

    items_d1_p1 =
      OrderItem
      |> Ash.Query.for_read(:in_range, %{
        start_date: start_dt1,
        end_date: end_dt1,
        product_ids: [p1.id]
      })
      |> Ash.read!()

    assert length(items_d1_p1) == 1
    assert Enum.all?(items_d1_p1, &(&1.product_id == p1.id))
  end
end
