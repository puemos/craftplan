defmodule CraftplanWeb.ManageProductsIndexInteractionsLiveTest do
  use CraftplanWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  alias Craftplan.Catalog.Product

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
    |> Ash.create!(actor: Craftplan.DataCase.staff_actor())
  end

  @tag role: :staff
  test "delete product from index stream", %{conn: conn} do
    p = create_product!()
    {:ok, view, _} = live(conn, ~p"/manage/products")

    # Click the delete link for this product by phx-value-id
    view
    |> element("a[phx-click]")
    |> render_click()

    assert render(view) =~ "Product deleted successfully"
    refute render(view) =~ p.sku
  end
end
