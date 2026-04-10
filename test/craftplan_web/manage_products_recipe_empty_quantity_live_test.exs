defmodule CraftplanWeb.ManageProductsRecipeEmptyQuantityLiveTest do
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
      price: Decimal.new("5.00"),
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
      price: Decimal.new("1.00"),
      minimum_stock: Decimal.new(0),
      maximum_stock: Decimal.new(0)
    })
    |> Ash.create!(actor: staff())
  end

  defp setup_product_with_bom(_context) do
    m = material!()
    p = product!()

    _bom =
      BOM
      |> Ash.Changeset.for_create(:create, %{
        product_id: p.id,
        status: :active,
        components: [%{component_type: :material, material_id: m.id, quantity: Decimal.new(1)}]
      })
      |> Ash.create!(actor: staff())

    %{product: p, material: m}
  end

  describe "empty quantity during IME composition" do
    setup [:setup_product_with_bom]

    @tag role: :staff
    test "empty quantity on validate does not crash", %{conn: conn, product: p, material: m} do
      {:ok, view, _html} = live(conn, ~p"/manage/products/#{p.sku}/recipe")

      view
      |> element("#recipe-form")
      |> render_change(%{
        "recipe" => %{"components" => %{"0" => %{"material_id" => m.id, "quantity" => ""}}}
      })

      assert has_element?(view, "#recipe-form")
    end

    @tag role: :staff
    test "whitespace-only quantity on validate does not crash", %{
      conn: conn,
      product: p,
      material: m
    } do
      {:ok, view, _html} = live(conn, ~p"/manage/products/#{p.sku}/recipe")

      view
      |> element("#recipe-form")
      |> render_change(%{
        "recipe" => %{"components" => %{"0" => %{"material_id" => m.id, "quantity" => "   "}}}
      })

      assert has_element?(view, "#recipe-form")
    end

    @tag role: :staff
    test "valid quantity still works after fix", %{conn: conn, product: p, material: m} do
      {:ok, view, _html} = live(conn, ~p"/manage/products/#{p.sku}/recipe")

      view
      |> element("#recipe-form")
      |> render_change(%{
        "recipe" => %{"components" => %{"0" => %{"material_id" => m.id, "quantity" => "2.5"}}}
      })

      view
      |> element("#recipe-form")
      |> render_submit(%{
        "recipe" => %{"components" => %{"0" => %{"material_id" => m.id, "quantity" => "2.5"}}}
      })

      assert render(view) =~ "Recipe saved successfully"
    end
  end
end
