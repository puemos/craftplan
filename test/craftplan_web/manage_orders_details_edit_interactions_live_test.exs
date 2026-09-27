defmodule CraftplanWeb.ManageOrdersDetailsEditInteractionsLiveTest do
  @moduledoc false

  use CraftplanWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Craftplan.Catalog.Product
  alias Craftplan.CRM.Customer
  alias Craftplan.Orders.Order

  defp create_customer! do
    Customer
    |> Ash.Changeset.for_create(:create, %{
      type: :individual,
      first_name: "Ada",
      last_name: "Lovelace"
    })
    |> Ash.create!()
  end

  defp create_product! do
    Product
    |> Ash.Changeset.for_create(:create, %{
      name: "P-#{System.unique_integer()}",
      sku: "SKU-#{System.unique_integer()}",
      price: Decimal.new("3.50"),
      status: :active
    })
    |> Ash.create!(actor: Craftplan.DataCase.staff_actor())
  end

  defp create_order!(customer, product) do
    Order
    |> Ash.Changeset.for_create(:create, %{
      customer_id: customer.id,
      delivery_date: DateTime.utc_now(),
      items: [%{"product_id" => product.id, "quantity" => 1, "unit_price" => product.price}]
    })
    |> Ash.create!(actor: Craftplan.DataCase.staff_actor())
  end

  @tag role: :staff
  test "edit order details and save", %{conn: conn} do
    c = create_customer!()
    p = create_product!()
    o = create_order!(c, p)

    {:ok, view, _} = live(conn, ~p"/manage/orders/#{o.reference}/edit")

    view
    |> form("#order-item-form", order: %{status: "confirmed", payment_status: "paid"})
    |> render_submit(%{"timezone" => "Etc/UTC"})

    assert_patch(view, ~p"/manage/orders/#{o.reference}")
    updated = Craftplan.Orders.get_order_by_id!(o.id, actor: Craftplan.DataCase.staff_actor())
    assert updated.status == :confirmed
    assert updated.payment_status == :paid
    assert Decimal.equal?(updated.subtotal, o.subtotal)
  end

  @tag role: :staff
  test "orders and customer history expose edit links", %{conn: conn} do
    customer = create_customer!()
    order = create_order!(customer, create_product!())
    path = ~p"/manage/orders/#{order.reference}/edit"

    {:ok, view, _} = live(conn, ~p"/manage/orders")
    assert has_element?(view, "#edit-order-#{order.id}[href='#{path}']")

    {:ok, view, _} = live(conn, ~p"/manage/customers/#{customer.reference}/orders")
    assert has_element?(view, "#edit-customer-order-#{order.id}[href='#{path}']")
  end

  @tag role: :staff
  test "removing a product persists and retains the remaining item's original price", %{
    conn: conn
  } do
    customer = create_customer!()
    product = create_product!()
    other = create_product!()

    order =
      Order
      |> Ash.Changeset.for_create(:create, %{
        customer_id: customer.id,
        delivery_date: DateTime.utc_now(),
        items: [
          %{product_id: product.id, quantity: 1, unit_price: Decimal.new("2.00")},
          %{product_id: other.id, quantity: 1, unit_price: other.price}
        ]
      })
      |> Ash.create!(actor: Craftplan.DataCase.staff_actor())

    {:ok, view, _} = live(conn, ~p"/manage/orders/#{order.reference}/edit")

    # Find the nested form for the product to remove without assuming database order.
    [input] =
      view
      |> element("#order-item-form")
      |> render()
      |> LazyHTML.from_fragment()
      |> LazyHTML.query("input[name$='[product_id]'][value='#{other.id}']")
      |> LazyHTML.attribute("name")

    path = String.replace_suffix(input, "[product_id]", "")

    view
    |> element("button[phx-click='remove_form'][phx-value-path='#{path}']")
    |> render_click()

    refute has_element?(view, "#order-item-form button[phx-disable-with][disabled]")

    view
    |> form("#order-item-form")
    |> render_submit(%{"timezone" => "Etc/UTC"})

    assert_patch(view, ~p"/manage/orders/#{order.reference}")

    updated =
      Craftplan.Orders.get_order_by_id!(order.id,
        actor: Craftplan.DataCase.staff_actor(),
        load: [:items]
      )

    assert [item] = updated.items
    assert item.product_id == product.id
    assert Decimal.equal?(item.unit_price, Decimal.new("2.00"))
    assert Decimal.equal?(updated.subtotal, Decimal.new("2.00"))
  end

  @tag role: :staff
  test "deleting an order removes its items", %{conn: conn} do
    order = create_order!(create_customer!(), create_product!())
    {:ok, view, _} = live(conn, ~p"/manage/orders/#{order.reference}")
    assert has_element?(view, "#delete-order[data-confirm]")

    view |> element("#delete-order") |> render_click()

    assert_redirect(view, ~p"/manage/orders")

    assert {:error, _} =
             Craftplan.Orders.get_order_by_id(order.id, actor: Craftplan.DataCase.staff_actor())

    assert {:error, _} =
             Craftplan.Orders.get_order_item_by_id(hd(order.items).id,
               actor: Craftplan.DataCase.staff_actor()
             )
  end

  @tag role: :staff
  test "production allocations prevent order deletion", %{conn: conn} do
    product = create_product!()
    order = create_order!(create_customer!(), product)
    actor = Craftplan.DataCase.staff_actor()

    batch =
      Craftplan.Orders.ProductionBatch
      |> Ash.Changeset.for_create(:open, %{product_id: product.id, planned_qty: Decimal.new(1)})
      |> Ash.create!(actor: actor)

    Craftplan.Orders.create_order_item_batch_allocation!(
      %{
        order_item_id: hd(order.items).id,
        production_batch_id: batch.id,
        planned_qty: Decimal.new(1)
      },
      actor: actor
    )

    {:ok, view, _} = live(conn, ~p"/manage/orders/#{order.reference}")
    view |> element("#delete-order") |> render_click()

    assert has_element?(view, "#flash-error", "Could not delete this order")
    assert {:ok, _} = Craftplan.Orders.get_order_by_id(order.id, actor: actor)
    assert {:ok, _} = Craftplan.Orders.get_order_item_by_id(hd(order.items).id, actor: actor)
  end
end
