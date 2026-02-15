defmodule CraftplanWeb.ManageProductsNutritionLiveTest do
  use CraftplanWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Craftplan.Catalog.BOM
  alias Craftplan.Catalog.Product
  alias Craftplan.Inventory.Material
  alias Craftplan.Inventory.MaterialNutritionalFact
  alias Craftplan.Inventory.NutritionalFact

  defp staff, do: Craftplan.DataCase.staff_actor()

  defp product! do
    Product
    |> Ash.Changeset.for_create(:create, %{
      name: "P-#{System.unique_integer()}",
      sku: "SKU-#{System.unique_integer()}",
      price: Money.new("5.00", :USD),
      status: :active
    })
    |> Ash.create!(actor: staff())
  end

  defp material_with_fact! do
    material =
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

    fact =
      NutritionalFact
      |> Ash.Changeset.for_create(:create, %{name: "Calories"})
      |> Ash.create!(actor: staff())

    _link =
      MaterialNutritionalFact
      |> Ash.Changeset.for_create(:create, %{
        material_id: material.id,
        nutritional_fact_id: fact.id,
        amount: Decimal.new("57"),
        unit: :gram
      })
      |> Ash.create!(actor: staff())

    Ash.reload!(material, load: [material_nutritional_facts: [nutritional_fact: [:name]]])
  end

  @tag role: :staff
  test "nutrition tab renders with facts derived from BOM", %{conn: conn} do
    m = material_with_fact!()
    p = product!()

    _bom =
      BOM
      |> Ash.Changeset.for_create(:create, %{
        product_id: p.id,
        status: :active,
        components: [%{component_type: :material, material_id: m.id, quantity: Decimal.new(2)}]
      })
      |> Ash.create!(actor: staff())

    {:ok, _view, html} = live(conn, ~p"/manage/products/#{p.sku}/nutrition")

    assert html =~ "Nutritional Facts"
    assert html =~ "Calories"
  end
end
