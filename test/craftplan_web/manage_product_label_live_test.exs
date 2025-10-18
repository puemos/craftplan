defmodule CraftplanWeb.ManageProductLabelLiveTest do
  use CraftplanWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Craftplan.Catalog.Product
  alias Craftplan.Catalog.Recipe
  alias Craftplan.Inventory.Allergen
  alias Craftplan.Inventory.Material
  alias Craftplan.Inventory.MaterialAllergen

  defp staff_user! do
    Craftplan.DataCase.staff_actor()
  end

  defp sign_in(conn, user) do
    conn
    |> Plug.Test.put_req_cookie("timezone", "Etc/UTC")
    |> AshAuthentication.Phoenix.Plug.store_in_session(user)
    |> Plug.Conn.assign(:current_user, user)
  end

  defp create_material_with_allergen!(name) do
    staff = staff_user!()

    material =
      Material
      |> Ash.Changeset.for_create(:create, %{
        name: name,
        sku: Base.encode16("MAT-" <> :crypto.strong_rand_bytes(4), case: :lower),
        unit: :gram,
        price: Decimal.new("1.00"),
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
    staff = staff_user!()

    product =
      Product
      |> Ash.Changeset.for_create(:create, %{
        name: "Sourdough Bread",
        sku: Base.encode16("SKU-" <> :crypto.strong_rand_bytes(4), case: :lower),
        status: :active,
        price: Decimal.new("6.50")
      })
      |> Ash.create!(actor: staff)

    material = create_material_with_allergen!("Flour")

    _recipe =
      Recipe
      |> Ash.Changeset.for_create(:create, %{
        product_id: product.id,
        components: [%{material_id: material.id, quantity: Decimal.new("500")}]
      })
      |> Ash.create!(actor: staff)

    # Load recipe/components and calculated allergens
    Ash.reload!(product, load: [:allergens, recipe: [components: [material: [:name]]]])
  end

  test "renders product label with ingredients and allergens", %{conn: conn} do
    staff = staff_user!()
    product = create_product_with_recipe!()

    conn = sign_in(conn, staff)

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
