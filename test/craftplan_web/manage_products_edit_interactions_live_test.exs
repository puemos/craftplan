defmodule CraftplanWeb.ManageProductsEditInteractionsLiveTest do
  use CraftplanWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  alias Craftplan.Catalog.Product

  defp create_product! do
    Product
    |> Ash.Changeset.for_create(:create, %{
      name: "P-#{System.unique_integer()}",
      sku: "SKU-#{System.unique_integer()}",
      price: Decimal.new("4.00"),
      status: :active
    })
    |> Ash.create!(actor: Craftplan.DataCase.staff_actor())
  end

  @tag role: :staff
  test "edit product name and save", %{conn: conn} do
    p = create_product!()
    {:ok, view, _} = live(conn, ~p"/manage/products/#{p.sku}/edit")

    params = %{"product" => %{"name" => p.name <> "X"}}

    view
    |> element("#product-form")
    |> render_submit(params)

    assert_patch(view, ~p"/manage/products/#{p.sku}/details")
    assert render(view) =~ "Product updated successfully"
  end
end
