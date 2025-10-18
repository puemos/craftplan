defmodule CraftplanWeb.PublicCatalogLiveTest do
  use CraftplanWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Craftplan.Accounts.User
  alias Craftplan.Catalog.Product

  defp staff_user! do
    User
    |> Ash.Changeset.for_create(:register_with_password, %{
      email: "staff+test@ex.com",
      password: "Passw0rd!!",
      password_confirmation: "Passw0rd!!",
      role: :staff
    })
    |> Ash.create!(
      context: %{
        strategy: AshAuthentication.Strategy.Password,
        private: %{ash_authentication?: true}
      }
    )
  end

  defp create_product!(attrs \\ %{}) do
    sku = attrs[:sku] || Base.encode16("SKU-" <> :crypto.strong_rand_bytes(4), case: :lower)
    name = attrs[:name] || "Test Product"
    price = attrs[:price] || Decimal.new("12.34")
    staff = staff_user!()

    Product
    |> Ash.Changeset.for_create(:create, %{name: name, sku: sku, status: :active, price: price})
    |> Ash.create!(actor: staff)
  end

  test "catalog index renders active product", %{conn: conn} do
    product = create_product!()
    conn = Plug.Conn.assign(conn, :current_user, nil)
    {:ok, _view, html} = live(conn, ~p"/catalog", on_error: :warn)
    assert html =~ product.name
  end

  test "product show allows add to cart for available product", %{conn: conn} do
    product = create_product!()
    conn = Plug.Conn.assign(conn, :current_user, nil)
    {:ok, view, _html} = live(conn, ~p"/catalog/#{product.sku}", on_error: :warn)

    view
    |> element("form[phx-submit=add_to_cart]")
    |> render_submit(%{"product_id" => product.id, "quantity" => "2"})

    # Flash confirms add
    assert render(view) =~ "Product added to cart"
  end
end
