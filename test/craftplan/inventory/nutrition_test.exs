defmodule Craftplan.Inventory.NutritionTest do
  use Craftplan.DataCase, async: true

  alias Craftplan.Catalog.BOM
  alias Craftplan.Catalog.Product
  alias Craftplan.Inventory.Material
  alias Craftplan.Inventory.MaterialNutritionalFact
  alias Craftplan.Inventory.Nutrition
  alias Craftplan.Inventory.NutritionalFact

  require Ash.Query

  defp staff, do: Craftplan.DataCase.staff_actor()

  defp material!(attrs \\ %{}) do
    Material
    |> Ash.Changeset.for_create(:create, %{
      name: Map.get(attrs, :name, "Material-#{System.unique_integer()}"),
      sku: Map.get(attrs, :sku, "MAT-#{System.unique_integer()}"),
      unit: Map.get(attrs, :unit, :gram),
      price: Map.get(attrs, :price, Decimal.new("1.00")),
      minimum_stock: Decimal.new(0),
      maximum_stock: Decimal.new(0)
    })
    |> Ash.create!(actor: staff())
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

  test "legacy EU nutrient names are normalized to locked canonical facts" do
    fact = fact!("Calories")

    assert fact.key == "energy_kcal"
    assert fact.name == "Energy (kcal)"
    assert fact.default_unit == :kcal
    assert fact.eu_required
    assert fact.system
  end

  test "custom facts get stable custom keys" do
    fact = fact!("Caffeine")

    assert fact.key == "custom:caffeine"
    refute fact.eu_required
    refute fact.system
  end

  test "system nutrition facts cannot be deleted" do
    fact = fact!("Salt")

    assert {:error, changeset} = Ash.destroy(fact, actor: staff())
    assert inspect(changeset.errors) =~ "system nutritional facts cannot be deleted"
  end

  test "material nutrition rejects child nutrients above parent nutrients" do
    material = material!()
    fat = fact!("Fat")
    saturates = fact!("Saturated Fat")

    params = %{
      material_nutritional_facts: [
        %{
          material_id: material.id,
          nutritional_fact_id: fat.id,
          amount: Decimal.new("5"),
          unit: :gram,
          basis_quantity: Decimal.new("100"),
          basis_unit: :gram
        },
        %{
          material_id: material.id,
          nutritional_fact_id: saturates.id,
          amount: Decimal.new("6"),
          unit: :gram,
          basis_quantity: Decimal.new("100"),
          basis_unit: :gram
        }
      ]
    }

    assert {:error, changeset} =
             material
             |> Ash.Changeset.for_update(:update_nutritional_facts, params)
             |> Ash.update(actor: staff())

    assert inspect(changeset.errors) =~ "saturates cannot exceed fat"
  end

  test "material nutrition rejects zero basis quantity" do
    material = material!()
    fat = fact!("Fat")

    params = %{
      material_nutritional_facts: [
        %{
          material_id: material.id,
          nutritional_fact_id: fat.id,
          amount: Decimal.new("5"),
          unit: :gram,
          basis_quantity: Decimal.new("0"),
          basis_unit: :gram
        }
      ]
    }

    assert {:error, changeset} =
             material
             |> Ash.Changeset.for_update(:update_nutritional_facts, params)
             |> Ash.update(actor: staff())

    assert inspect(changeset.errors) =~ "basis_quantity must be greater than zero"
  end

  test "product nutrition is calculated per 100g when finished output is set" do
    actor = staff()
    material = material!()
    fat = fact!("Fat")

    MaterialNutritionalFact
    |> Ash.Changeset.for_create(:create, %{
      material_id: material.id,
      nutritional_fact_id: fat.id,
      amount: Decimal.new("10"),
      unit: :gram,
      basis_quantity: Decimal.new("100"),
      basis_unit: :gram
    })
    |> Ash.create!(actor: actor)

    product =
      Product
      |> Ash.Changeset.for_create(:create, %{
        name: "Product-#{System.unique_integer()}",
        sku: "SKU-#{System.unique_integer()}",
        price: Decimal.new("5.00"),
        status: :active,
        nutrition_output_quantity: Decimal.new("200"),
        nutrition_output_unit: :gram
      })
      |> Ash.create!(actor: actor)

    BOM
    |> Ash.Changeset.for_create(:create, %{
      product_id: product.id,
      status: :active,
      components: [
        %{component_type: :material, material_id: material.id, quantity: Decimal.new("50")}
      ]
    })
    |> Ash.create!(actor: actor)

    product = Ash.load!(product, [:nutritional_facts], actor: actor)
    [fact] = product.nutritional_facts

    assert fact.key == "fat"
    assert fact.declaration?
    assert fact.per_quantity == Decimal.new("100")
    assert fact.per_unit == :gram
    assert Decimal.equal?(fact.amount, Decimal.new("2.5"))
  end
end
