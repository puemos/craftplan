defmodule CraftplanWeb.ManageOrdersLiveTest do
  use CraftplanWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Craftplan.Test.Factory

  describe "index and new" do
    @tag role: :staff
    test "renders orders index for staff", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/manage/orders")
      assert has_element?(view, "#orders")
    end

    @tag role: :staff
    test "renders new order modal for staff", %{conn: conn} do
      # ensure there is at least one customer and product so form options are present
      _product = Factory.create_product!()
      _customer = Factory.create_customer!()

      {:ok, view, _html} = live(conn, ~p"/manage/orders/new")
      assert has_element?(view, "#order-item-form")
    end
  end

  describe "show tabs" do
    @tag role: :staff
    test "renders order details for staff", %{conn: conn} do
      product = Factory.create_product!()
      customer = Factory.create_customer!()

      order =
        Factory.create_order_with_items!(customer, [
          %{product_id: product.id, quantity: 2, unit_price: product.price}
        ])

      {:ok, view, _html} = live(conn, ~p"/manage/orders/#{order.reference}")
      assert has_element?(view, "[role=tablist]")
      assert has_element?(view, "kbd")
    end

    @tag role: :staff
    test "renders items tab for staff", %{conn: conn} do
      product = Factory.create_product!()
      customer = Factory.create_customer!()

      order =
        Factory.create_order_with_items!(customer, [
          %{product_id: product.id, quantity: 2, unit_price: product.price}
        ])

      {:ok, view, _html} = live(conn, ~p"/manage/orders/#{order.reference}/items")
      assert has_element?(view, "#order-items")
    end

    @tag role: :staff
    test "renders edit modal for staff", %{conn: conn} do
      product = Factory.create_product!()
      customer = Factory.create_customer!()

      order =
        Factory.create_order_with_items!(customer, [
          %{product_id: product.id, quantity: 2, unit_price: product.price}
        ])

      {:ok, view, _html} = live(conn, ~p"/manage/orders/#{order.reference}/edit")
      assert has_element?(view, "#order-item-form")
    end

    @tag role: :staff
    test "renders invoice for staff", %{conn: conn} do
      product = Factory.create_product!()
      customer = Factory.create_customer!()

      order =
        Factory.create_order_with_items!(customer, [
          %{product_id: product.id, quantity: 2, unit_price: product.price}
        ])

      {:ok, view, _html} = live(conn, ~p"/manage/orders/#{order.reference}/invoice")
      assert has_element?(view, "#invoice-items")
    end
  end
end
