defmodule CraftplanWeb.ManageProductsDetailsLiveTest do
  use CraftplanWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Craftplan.Catalog.BOM
  alias Craftplan.Catalog.Product
  alias Craftplan.Inventory.Material

  defp staff, do: Craftplan.DataCase.staff_actor()

  defp product! do
    Product
    |> Ash.Changeset.for_create(:create, %{
      name: "P-#{System.unique_integer()}",
      sku: "SKU-#{System.unique_integer()}",
      price: Money.new("10.00", :USD),
      status: :active
    })
    |> Ash.create!(actor: staff())
  end

  defp material! do
    Material
    |> Ash.Changeset.for_create(:create, %{
      name: "Mat-#{System.unique_integer()}",
      sku: "MAT-#{System.unique_integer()}",
      unit: :gram,
      price: Money.new("1.00", :USD),
      minimum_stock: Decimal.new(0),
      maximum_stock: Decimal.new(0)
    })
    |> Ash.create!(actor: staff())
  end

  @tag role: :staff
  test "details tab renders pricing helpers using BOM unit cost", %{conn: conn} do
    m = material!()
    p = product!()

    _bom =
      BOM
      |> Ash.Changeset.for_create(:create, %{
        product_id: p.id,
        status: :active,
        components: [%{component_type: :material, material_id: m.id, quantity: Decimal.new(2)}]
      })
      |> Ash.create!(actor: staff())

    {:ok, _view, html} = live(conn, ~p"/manage/products/#{p.sku}/details")

    assert html =~ p.name
    assert html =~ "Materials cost"
    assert html =~ "Gross profit"
    assert html =~ "Markup percentage"
    assert html =~ "Suggested Prices"
  end
end
