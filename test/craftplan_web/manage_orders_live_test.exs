defmodule CraftplanWeb.ManageOrdersLiveTest do
  use CraftplanWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Craftplan.Catalog.Product
  alias Craftplan.CRM.Customer
  alias Craftplan.Orders.Order

  defp staff_user! do
    Craftplan.DataCase.staff_actor()
  end

  defp unique_sku do
    "sku-" <> Ecto.UUID.generate()
  end

  defp create_product!(attrs \\ %{}) do
    staff = staff_user!()
    name = Map.get(attrs, :name, "Order Test Product")
    sku = Map.get(attrs, :sku, unique_sku())
    price = Map.get(attrs, :price, Decimal.new("5.00"))
    status = Map.get(attrs, :status, :active)

    Product
    |> Ash.Changeset.for_create(:create, %{
      name: name,
      sku: sku,
      price: price,
      status: status
    })
    |> Ash.create!(actor: staff)
  end

  defp create_customer!(attrs \\ %{}) do
    first = Map.get(attrs, :first_name, "Jane")
    last = Map.get(attrs, :last_name, "Doe")
    email = Map.get(attrs, :email, "jane.doe+#{System.unique_integer()}@local")

    Customer
    |> Ash.Changeset.for_create(:create, %{
      type: :individual,
      first_name: first,
      last_name: last,
      email: email
    })
    |> Ash.create!()
  end

  defp create_order!(customer, product, attrs \\ %{}) do
    staff = staff_user!()
    delivery = Map.get(attrs, :delivery_date, DateTime.utc_now())

    Order
    |> Ash.Changeset.for_create(:create, %{
      customer_id: customer.id,
      delivery_date: delivery,
      items: [
        %{
          "product_id" => product.id,
          "quantity" => 2,
          "unit_price" => product.price
        }
      ]
    })
    |> Ash.create!(actor: staff)
  end

  defp sign_in(conn, user) do
    conn
    |> Plug.Test.put_req_cookie("timezone", "Etc/UTC")
    |> AshAuthentication.Phoenix.Plug.store_in_session(user)
    |> Plug.Conn.assign(:current_user, user)
  end

  describe "index and new" do
    test "renders orders index for staff", %{conn: conn} do
      staff = staff_user!()
      conn = sign_in(conn, staff)

      {:ok, view, _html} = live(conn, ~p"/manage/orders")
      assert has_element?(view, "#orders")
    end

    test "renders new order modal for staff", %{conn: conn} do
      # ensure there is at least one customer and product so form options are present
      _product = create_product!()
      _customer = create_customer!()

      staff = staff_user!()
      conn = sign_in(conn, staff)

      {:ok, view, _html} = live(conn, ~p"/manage/orders/new")
      assert has_element?(view, "#order-item-form")
    end
  end

  describe "show tabs" do
    test "renders order details for staff", %{conn: conn} do
      product = create_product!()
      customer = create_customer!()
      order = create_order!(customer, product)

      staff = staff_user!()
      conn = sign_in(conn, staff)

      {:ok, view, _html} = live(conn, ~p"/manage/orders/#{order.reference}")
      assert has_element?(view, "[role=tablist]")
      assert has_element?(view, "kbd")
    end

    test "renders items tab for staff", %{conn: conn} do
      product = create_product!()
      customer = create_customer!()
      order = create_order!(customer, product)

      staff = staff_user!()
      conn = sign_in(conn, staff)

      {:ok, view, _html} = live(conn, ~p"/manage/orders/#{order.reference}/items")
      assert has_element?(view, "#order-items")
    end

    test "renders edit modal for staff", %{conn: conn} do
      product = create_product!()
      customer = create_customer!()
      order = create_order!(customer, product)

      staff = staff_user!()
      conn = sign_in(conn, staff)

      {:ok, view, _html} = live(conn, ~p"/manage/orders/#{order.reference}/edit")
      assert has_element?(view, "#order-item-form")
    end

    test "renders invoice for staff", %{conn: conn} do
      product = create_product!()
      customer = create_customer!()
      order = create_order!(customer, product)

      staff = staff_user!()
      conn = sign_in(conn, staff)

      {:ok, view, _html} = live(conn, ~p"/manage/orders/#{order.reference}/invoice")
      assert has_element?(view, "#invoice-items")
    end
  end
end
