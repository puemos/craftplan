defmodule CraftplanWeb.PublicOrderStatusLiveTest do
  use CraftplanWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Craftplan.Catalog.Product
  alias Craftplan.CRM.Customer
  alias Craftplan.Orders.Order

  defp staff_actor, do: Craftplan.DataCase.staff_actor()

  defp create_customer!(attrs \\ %{}) do
    first_name = Map.get(attrs, :first_name, "Jane")
    last_name = Map.get(attrs, :last_name, "Doe")
    email = Map.get(attrs, :email, "jane.doe@example.com")

    Customer
    |> Ash.Changeset.for_create(:create, %{
      type: :individual,
      first_name: first_name,
      last_name: last_name,
      email: email
    })
    |> Ash.create!()
  end

  defp create_product!(attrs \\ %{}) do
    sku = attrs[:sku] || Base.encode16("SKU-" <> :crypto.strong_rand_bytes(4), case: :lower)
    name = attrs[:name] || "Test Product"
    price = attrs[:price] || Decimal.new("9.99")

    Product
    |> Ash.Changeset.for_create(:create, %{name: name, sku: sku, status: :active, price: price})
    |> Ash.create!(actor: staff_actor())
  end

  defp create_order_with_item! do
    staff = staff_actor()
    customer = create_customer!()
    product = create_product!()

    {:ok, order} =
      Order
      |> Ash.Changeset.for_create(:create, %{
        customer_id: customer.id,
        delivery_date: DateTime.utc_now(),
        items: [
          %{product_id: product.id, quantity: 2, unit_price: product.price, status: :todo}
        ]
      })
      |> Ash.create(actor: staff)

    Ash.reload!(order, load: [items: [product: [:name, :sku]]], actor: staff)
  end

  test "shows not found for invalid reference", %{conn: conn} do
    conn = Plug.Test.put_req_cookie(conn, "timezone", "Etc/UTC")
    {:ok, _view, html} = live(conn, ~p"/o/OR_9999_99_99_XXXXXX", on_error: :warn)
    assert html =~ "Order not found"
  end

  test "renders order details for valid reference", %{conn: conn} do
    order = create_order_with_item!()

    conn =
      conn
      |> Plug.Conn.assign(:current_user, nil)
      |> Plug.Test.put_req_cookie("timezone", "Etc/UTC")

    {:ok, view, _html} = live(conn, ~p"/o/#{order.reference}", on_error: :warn)

    html = render(view)
    # Page scaffolding
    assert html =~ "Order Status"
    refute html =~ "Order not found"
  end
end
