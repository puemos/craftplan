defmodule CraftdayWeb.ManageProductsLiveTest do
  use CraftdayWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Craftday.Catalog.Product

  defp staff_user! do
    Craftday.DataCase.staff_actor()
  end

  defp unique_sku do
    "sku-" <> Ecto.UUID.generate()
  end

  defp create_product!(attrs \\ %{}) do
    staff = staff_user!()
    name = Map.get(attrs, :name, "Test Product")
    sku = Map.get(attrs, :sku, unique_sku())
    price = Map.get(attrs, :price, Decimal.new("9.99"))
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

  defp sign_in(conn, user) do
    conn
    |> AshAuthentication.Phoenix.Plug.store_in_session(user)
    |> Plug.Conn.assign(:current_user, user)
  end

  describe "index and new" do
    test "renders index for staff", %{conn: conn} do
      staff = staff_user!()
      conn = sign_in(conn, staff)

      {:ok, view, _html} = live(conn, ~p"/manage/products")
      assert has_element?(view, "#products")
    end

    test "renders new product modal and creates product", %{conn: conn} do
      staff = staff_user!()
      conn = sign_in(conn, staff)

      {:ok, view, _html} = live(conn, ~p"/manage/products/new")

      assert has_element?(view, "#product-form")

      params = %{
        "product" => %{
          "name" => "New Product",
          "sku" => unique_sku(),
          "price" => "12.34"
        }
      }

      view
      |> element("#product-form")
      |> render_submit(params)

      assert_patch(view, ~p"/manage/products")
      assert render(view) =~ "Product created successfully"
    end
  end

  describe "show tabs" do
    test "renders details tab for staff", %{conn: conn} do
      product = create_product!()
      staff = staff_user!()
      conn = sign_in(conn, staff)

      {:ok, view, _html} = live(conn, ~p"/manage/products/#{product.sku}")

      assert has_element?(view, "[role=tablist]")
      assert has_element?(view, "kbd")
    end

    test "renders recipe tab for staff", %{conn: conn} do
      product = create_product!()
      staff = staff_user!()
      conn = sign_in(conn, staff)

      {:ok, view, _html} = live(conn, ~p"/manage/products/#{product.sku}/recipe")

      assert has_element?(view, "[role=tablist]")
      assert has_element?(view, "#recipe-form")
    end

    test "renders nutrition tab for staff", %{conn: conn} do
      product = create_product!()
      staff = staff_user!()
      conn = sign_in(conn, staff)

      {:ok, view, _html} = live(conn, ~p"/manage/products/#{product.sku}/nutrition")

      assert has_element?(view, "[role=tablist]")
      assert has_element?(view, "#nutritional-facts")
    end

    test "renders photos tab for staff", %{conn: conn} do
      product = create_product!()
      staff = staff_user!()
      conn = sign_in(conn, staff)

      {:ok, view, _html} = live(conn, ~p"/manage/products/#{product.sku}/photos")

      assert has_element?(view, "[role=tablist]")
      assert has_element?(view, "h3", "Product Photos")
    end

    test "renders edit modal for staff", %{conn: conn} do
      product = create_product!()
      staff = staff_user!()
      conn = sign_in(conn, staff)

      {:ok, view, _html} = live(conn, ~p"/manage/products/#{product.sku}/edit")

      assert has_element?(view, "#product-form")
    end
  end
end
