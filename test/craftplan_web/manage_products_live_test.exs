defmodule CraftplanWeb.ManageProductsLiveTest do
  use CraftplanWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Craftplan.Test.Factory

  describe "index and new" do
    @tag role: :staff
    test "renders index for staff", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/manage/products")
      assert has_element?(view, "#products")
    end

    @tag role: :staff
    test "renders new product modal and creates product", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/manage/products/new")

      assert has_element?(view, "#product-form")

      params = %{
        "product" => %{
          "name" => "New Product",
          "sku" => "sku-" <> Ecto.UUID.generate(),
          "price" => "12.34"
        }
      }

      view
      |> element("#product-form")
      |> render_submit(params)

      assert_patch(view, ~p"/manage/products")
      assert render(view) =~ "Product created successfully"
    end

    @tag role: :staff
    test "index renders products with cost calculations without crashing", %{conn: conn} do
      # Create a product with a simple BOM so calculations run
      material = Factory.create_material!(%{price: Decimal.new("1.00"), unit: :gram})
      product = Factory.create_product!(%{price: Decimal.new("3.99"), status: :active})

      _bom =
        Craftplan.Catalog.BOM
        |> Ash.Changeset.for_create(:create, %{
          product_id: product.id,
          components: [
            %{component_type: :material, material_id: material.id, quantity: Decimal.new(1)}
          ]
        })
        |> Ash.create!(actor: Craftplan.DataCase.staff_actor())

      {:ok, view, html} = live(conn, ~p"/manage/products")
      assert has_element?(view, "#products")
      assert html =~ product.name
    end
  end

  describe "show tabs" do
    @tag role: :staff
    test "renders details tab for staff", %{conn: conn} do
      product = Factory.create_product!()

      {:ok, view, _html} = live(conn, ~p"/manage/products/#{product.sku}")

      assert has_element?(view, "[role=tablist]")
      assert has_element?(view, "kbd")
    end

    @tag role: :staff
    test "renders recipe tab for staff", %{conn: conn} do
      product = Factory.create_product!()

      {:ok, view, _html} = live(conn, ~p"/manage/products/#{product.sku}/recipe")

      assert has_element?(view, "[role=tablist]")
      assert has_element?(view, "#recipe-form")
    end

    @tag role: :staff
    test "renders nutrition tab for staff", %{conn: conn} do
      product = Factory.create_product!()

      {:ok, view, _html} = live(conn, ~p"/manage/products/#{product.sku}/nutrition")

      assert has_element?(view, "[role=tablist]")
      assert has_element?(view, "#nutritional-facts")
    end

    @tag role: :staff
    test "renders photos tab for staff", %{conn: conn} do
      product = Factory.create_product!()

      {:ok, view, _html} = live(conn, ~p"/manage/products/#{product.sku}/photos")

      assert has_element?(view, "[role=tablist]")
      assert has_element?(view, "h3", "Product Photos")
    end

    @tag role: :staff
    test "renders edit modal for staff", %{conn: conn} do
      product = Factory.create_product!()

      {:ok, view, _html} = live(conn, ~p"/manage/products/#{product.sku}/edit")

      assert has_element?(view, "#product-form")
    end
  end
end
