defmodule CraftdayWeb.ManageProductsIndexInteractionsLiveTest do
  use CraftdayWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Craftday.Catalog.Product

  defp staff_user! do
    Craftday.DataCase.staff_actor()
  end

  defp sign_in(conn, user) do
    conn
    |> Plug.Test.put_req_cookie("timezone", "Etc/UTC")
    |> AshAuthentication.Phoenix.Plug.store_in_session(user)
    |> Plug.Conn.assign(:current_user, user)
  end

  defp create_product!(attrs \\ %{}) do
    name = Map.get(attrs, :name, "P-#{System.unique_integer()}")
    sku = Map.get(attrs, :sku, "SKU-#{System.unique_integer()}")
    price = Map.get(attrs, :price, Decimal.new("4.00"))
    status = Map.get(attrs, :status, :active)

    Product
    |> Ash.Changeset.for_create(:create, %{
      name: name,
      sku: sku,
      price: price,
      status: status
    })
    |> Ash.create!(actor: staff_user!())
  end

  test "delete product from index stream", %{conn: conn} do
    p = create_product!()
    conn = sign_in(conn, staff_user!())
    {:ok, view, _} = live(conn, ~p"/manage/products")

    # Click the delete link for this product by phx-value-id
    view
    |> element("a[phx-click]")
    |> render_click()

    assert render(view) =~ "Product deleted successfully"
    refute render(view) =~ p.sku
  end
end
