defmodule Craftplan.Orders.TotalsUpdateAfterItemsTest do
  use Craftplan.DataCase, async: true

  alias Craftplan.Catalog
  alias Craftplan.CRM
  alias Craftplan.Orders

  test "update action recalculates totals after items are added" do
    {:ok, customer} =
      CRM.Customer
      |> Ash.Changeset.for_create(:create, %{
        type: :individual,
        first_name: "Taylor",
        last_name: "Seed",
        email: "seed@example.com"
      })
      |> Ash.create()

    staff = Craftplan.DataCase.staff_actor()

    {:ok, product} =
      Catalog.Product
      |> Ash.Changeset.for_create(:create, %{
        name: "Widget",
        status: :active,
        price: Money.new("3.25", :EUR),
        sku: "W-1"
      })
      |> Ash.create(actor: staff)

    {:ok, order} =
      Orders.Order
      |> Ash.Changeset.for_create(:create, %{
        customer_id: customer.id,
        delivery_date: DateTime.utc_now(),
        currency: :EUR
      })
      |> Ash.create(actor: staff)

    assert order.subtotal == Money.new(0, :EUR)
    assert order.total == Money.new(0, :EUR)

    {:ok, order} =
      order
      |> Ash.Changeset.for_update(:update, %{
        items: [
          %{
            product_id: product.id,
            quantity: Decimal.new(4),
            unit_price: Money.new("3.25", :EUR)
          }
        ]
      })
      |> Ash.update(actor: staff)

    {:ok, order_after} = Orders.get_order_by_id(order.id, actor: staff)

    assert order_after.subtotal == Money.new("13.00", :EUR)
    assert order_after.total == Money.new("13.00", :EUR)
  end
end
