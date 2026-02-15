defmodule Craftplan.Orders.EmailsTest do
  use Craftplan.DataCase, async: true

  import Swoosh.TestAssertions

  alias Craftplan.Catalog
  alias Craftplan.CRM
  alias Craftplan.Orders
  alias Craftplan.Orders.Emails

  test "delivers order confirmation email" do
    staff = Craftplan.DataCase.staff_actor()

    {:ok, customer} =
      CRM.Customer
      |> Ash.Changeset.for_create(:create, %{
        type: :individual,
        first_name: "Pat",
        last_name: "Buyer",
        email: "buyer@example.com"
      })
      |> Ash.create()

    {:ok, product} =
      Catalog.Product
      |> Ash.Changeset.for_create(:create, %{
        name: "Email Test Product",
        status: :active,
        price: Money.new("9.99", :USD),
        sku: "EMAIL-1"
      })
      |> Ash.create(actor: staff)

    {:ok, order} =
      Orders.Order
      |> Ash.Changeset.for_create(:create, %{
        customer_id: customer.id,
        delivery_date: DateTime.utc_now(),
        items: [%{product_id: product.id, quantity: Decimal.new(1), unit_price: product.price}]
      })
      |> Ash.create(actor: staff)

    order = Ash.load!(order, [items: [product: [:name]], customer: [:email]], actor: staff)
    assert order.customer.email == "buyer@example.com"

    assert {:ok, _} = Emails.deliver_order_confirmation(order)

    # Drain any prior auth-related email (e.g., staff registration)
    assert_email_sent()

    assert_email_sent(fn email ->
      assert Enum.any?(email.to, fn {_name, addr} -> addr == "buyer@example.com" end)
      assert String.contains?(email.subject, order.reference)
    end)
  end
end
