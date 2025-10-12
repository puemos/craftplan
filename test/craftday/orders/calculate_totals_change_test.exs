defmodule Craftday.Orders.CalculateTotalsChangeTest do
  use Craftday.DataCase, async: true

  alias Craftday.Catalog
  alias Craftday.CRM
  alias Craftday.Orders

  test "sets subtotal and total from items" do
    staff = Craftday.DataCase.staff_actor()
    # Create a customer
    {:ok, customer} =
      CRM.Customer
      |> Ash.Changeset.for_create(:create, %{
        type: :individual,
        first_name: "John",
        last_name: "Doe",
        email: "jdoe@example.com"
      })
      |> Ash.create()

    # Create a product
    {:ok, product} =
      Catalog.Product
      |> Ash.Changeset.for_create(:create, %{
        name: "Test Product",
        status: :active,
        price: Decimal.new("12.50"),
        sku: "TP-001"
      })
      |> Ash.create(actor: staff)

    # Create an order with items
    items = [
      %{
        product_id: product.id,
        quantity: Decimal.new(2),
        unit_price: product.price
      }
    ]

    {:ok, order} =
      Orders.Order
      |> Ash.Changeset.for_create(:create, %{
        customer_id: customer.id,
        delivery_date: DateTime.utc_now(),
        items: items
      })
      |> Ash.create(actor: staff)

    assert order.subtotal == Decimal.new("25.00")
    assert order.total == Decimal.new("25.00")
  end
end
