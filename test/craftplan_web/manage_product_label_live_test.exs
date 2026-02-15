defmodule CraftplanWeb.ManageProductLabelLiveTest do
  use CraftplanWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Craftplan.Catalog.BOM
  alias Craftplan.Catalog.Product
  alias Craftplan.Inventory.Allergen
  alias Craftplan.Inventory.Material
  alias Craftplan.Inventory.MaterialAllergen

  defp create_material_with_allergen!(name) do
    staff = Craftplan.DataCase.staff_actor()

    material =
      Material
      |> Ash.Changeset.for_create(:create, %{
        name: name,
        sku: Base.encode16("MAT-" <> :crypto.strong_rand_bytes(4), case: :lower),
        unit: :gram,
        price: Money.new("1.00", :USD),
        minimum_stock: Decimal.new("0"),
        maximum_stock: Decimal.new("10000")
      })
      |> Ash.create!(actor: staff)

    allergen =
      Allergen
      |> Ash.Changeset.for_create(:create, %{name: "Gluten"})
      |> Ash.create!(actor: staff)

    _ =
      MaterialAllergen
      |> Ash.Changeset.for_create(:create, %{material_id: material.id, allergen_id: allergen.id})
      |> Ash.create!(actor: staff)

    Ash.reload!(material, load: [:allergens])
  end

  defp create_product_with_recipe! do
    staff = Craftplan.DataCase.staff_actor()

    product =
      Product
      |> Ash.Changeset.for_create(:create, %{
        name: "Sourdough Bread",
        sku: Base.encode16("SKU-" <> :crypto.strong_rand_bytes(4), case: :lower),
        status: :active,
        price: Money.new("6.50", :USD)
      })
      |> Ash.create!(actor: staff)

    material = create_material_with_allergen!("Flour")

    _bom =
      BOM
      |> Ash.Changeset.for_create(:create, %{
        product_id: product.id,
        components: [
          %{component_type: :material, material_id: material.id, quantity: Decimal.new("500")}
        ]
      })
      |> Ash.create!(actor: staff)

    # Load allergens via BOM path
    Ash.reload!(product, load: [:allergens, active_bom: [components: [material: [:name]]]])
  end

  @tag role: :staff
  test "renders product label with ingredients and allergens", %{conn: conn} do
    product = create_product_with_recipe!()

    {:ok, _view, html} = live(conn, ~p"/manage/products/#{product.sku}/label")

    assert html =~ "Product Label"
    assert html =~ product.name
    # Ingredient name from recipe component
    assert html =~ "Flour"
    # Allergen badge text
    assert html =~ "Gluten"
    # Batch code prefix
    assert html =~ "Batch"
  end
end
