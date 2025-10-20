defmodule CraftplanWeb.PrintViewsTest do
  use CraftplanWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Craftplan.Catalog.Product
  alias Craftplan.CRM.Customer
  alias Craftplan.Orders.Order

  defp staff, do: Craftplan.DataCase.staff_actor()

  defp create_product!(attrs \\ %{}) do
    Product
    |> Ash.Changeset.for_create(:create, %{
      name: Map.get(attrs, :name, "Print Test Product"),
      sku: Map.get(attrs, :sku, "SKU-" <> Ecto.UUID.generate()),
      status: :active,
      price: Map.get(attrs, :price, Decimal.new("5.00"))
    })
    |> Ash.create!(actor: staff())
  end

  defp create_order_with_item! do
    prod = create_product!()

    cust =
      Customer
      |> Ash.Changeset.for_create(:create, %{
        type: :individual,
        first_name: "Jane",
        last_name: "Doe"
      })
      |> Ash.create!()

    {:ok, order} =
      Order
      |> Ash.Changeset.for_create(:create, %{
        customer_id: cust.id,
        delivery_date: DateTime.utc_now(),
        items: [%{"product_id" => prod.id, "quantity" => 1, "unit_price" => prod.price}]
      })
      |> Ash.create(actor: staff())

    Ash.reload!(order, load: [items: [product: [:name]]], actor: staff())
  end

  @tag role: :staff
  test "invoice view contains print classes", %{conn: conn} do
    order = create_order_with_item!()
    {:ok, _view, html} = live(conn, ~p"/manage/orders/#{order.reference}/invoice")

    assert html =~ "print:max-w-full"
    assert html =~ "print:hidden"
  end

  @tag role: :staff
  test "make sheet contains print classes", %{conn: conn} do
    {:ok, _view, html} = live(conn, ~p"/manage/production/make_sheet")

    # Buttons hidden in print, containers adjust for print
    assert html =~ "print:hidden"
    assert html =~ "print:border-black"
  end

  @tag role: :staff
  test "product label contains print classes", %{conn: conn} do
    prod = create_product!()
    {:ok, _view, html} = live(conn, ~p"/manage/products/#{prod.sku}/label")

    assert html =~ "print:max-w-full"
    assert html =~ "print:hidden"
  end
end
