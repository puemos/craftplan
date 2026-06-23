defmodule CraftplanWeb.ManageProductsNutritionLiveTest do
  use CraftplanWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Craftplan.Catalog.BOM
  alias Craftplan.Catalog.Product
  alias Craftplan.Inventory.Material
  alias Craftplan.Inventory.MaterialNutritionalFact
  alias Craftplan.Inventory.Nutrition
  alias Craftplan.Inventory.NutritionalFact

  require Ash.Query

  defp staff, do: Craftplan.DataCase.staff_actor()

  defp product!(attrs \\ %{}) do
    Product
    |> Ash.Changeset.for_create(:create, %{
      name: "P-#{System.unique_integer()}",
      sku: "SKU-#{System.unique_integer()}",
      price: Decimal.new("5.00"),
      status: :active,
      nutrition_output_quantity: Map.get(attrs, :nutrition_output_quantity),
      nutrition_output_unit: Map.get(attrs, :nutrition_output_unit)
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
        price: Decimal.new("1.00"),
        minimum_stock: Decimal.new(0),
        maximum_stock: Decimal.new(0)
      })
      |> Ash.create!(actor: staff())

    fact = fact!("Calories")

    _link =
      MaterialNutritionalFact
      |> Ash.Changeset.for_create(:create, %{
        material_id: material.id,
        nutritional_fact_id: fact.id,
        amount: Decimal.new("57"),
        unit: :kcal,
        basis_quantity: Decimal.new("100"),
        basis_unit: :gram
      })
      |> Ash.create!(actor: staff())

    Ash.reload!(material, load: [material_nutritional_facts: [nutritional_fact: [:name]]])
  end

  defp fact!(name) do
    key = Nutrition.standard_key_for_name(name) || Nutrition.custom_key(name)

    case NutritionalFact |> Ash.Query.filter(key == ^key) |> Ash.read_one!(authorize?: false) do
      nil ->
        NutritionalFact
        |> Ash.Changeset.for_create(:create, %{name: name})
        |> Ash.create!(actor: staff())

      fact ->
        fact
    end
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
    assert html =~ "Energy (kcal)"
  end

  @tag role: :staff
  test "nutrition tab renders per-100g declaration when product output is set", %{conn: conn} do
    m = material_with_fact!()
    p = product!(%{nutrition_output_quantity: Decimal.new("100"), nutrition_output_unit: :gram})

    _bom =
      BOM
      |> Ash.Changeset.for_create(:create, %{
        product_id: p.id,
        status: :active,
        components: [%{component_type: :material, material_id: m.id, quantity: Decimal.new(2)}]
      })
      |> Ash.create!(actor: staff())

    {:ok, _view, html} = live(conn, ~p"/manage/products/#{p.sku}/nutrition")

    assert html =~ "Nutrition Declaration"
    assert html =~ "Per 100 g"
  end
end
