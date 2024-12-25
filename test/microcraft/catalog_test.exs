defmodule Microcraft.CatalogTest do
  use Microcraft.DataCase
  alias Microcraft.Catalog
  alias Microcraft.Warehouse

  describe "products" do
    test "creates product with valid attributes" do
      attrs = %{
        name: "Wooden Chair",
        status: :experiment,
        price: Decimal.new(2500)
      }

      assert {:ok, product} = Ash.create(Catalog.Product, attrs)
      assert product.name == "Wooden Chair"
      assert product.status == :experiment
      assert product.price == Decimal.new(2500)
    end
  end

  describe "recipes" do
    setup do
      {:ok, product} =
        Ash.create(Catalog.Product, %{
          name: "Wooden Chair",
          status: :experiment,
          price: Decimal.new(2500)
        })

      {:ok, material1} =
        Ash.create(Warehouse.Material, %{
          name: "Wood",
          sku: "WD-001",
          unit: :piece,
          price: Decimal.new(500),
          minimum_stock: 10,
          maximum_stock: 100
        })

      {:ok, material2} =
        Ash.create(Warehouse.Material, %{
          name: "Nails",
          sku: "NL-001",
          unit: :piece,
          price: Decimal.new(100),
          minimum_stock: 50,
          maximum_stock: 500
        })

      {:ok, recipe} =
        Ash.create(Catalog.Recipe, %{
          product_id: product.id,
          instructions: "1. Cut wood\n2. Assemble with nails"
        })

      %{
        product: product,
        material1: material1,
        material2: material2,
        recipe: recipe
      }
    end

    test "creates recipe with materials", %{
      recipe: recipe,
      material1: material1,
      material2: material2
    } do
      assert {:ok, _recipe_material1} =
               Ash.create(Catalog.RecipeMaterial, %{
                 recipe_id: recipe.id,
                 material_id: material1.id,
                 quantity: 4
               })

      assert {:ok, _recipe_material2} =
               Ash.create(Catalog.RecipeMaterial, %{
                 recipe_id: recipe.id,
                 material_id: material2.id,
                 quantity: 12
               })

      loaded_recipe =
        recipe
        |> Ash.load!(recipe_materials: [:material])

      assert length(loaded_recipe.recipe_materials) == 2
    end

    test "calculates recipe total cost", %{
      recipe: recipe,
      material1: material1,
      material2: material2
    } do
      {:ok, _} =
        Ash.create(Catalog.RecipeMaterial, %{
          recipe_id: recipe.id,
          material_id: material1.id,
          quantity: 4
        })

      {:ok, _} =
        Ash.create(Catalog.RecipeMaterial, %{
          recipe_id: recipe.id,
          material_id: material2.id,
          quantity: 12
        })

      {:ok, recipe_with_cost} =
        recipe
        |> Ash.load(:cost)

      # 4 * $5.00 (wood) + 12 * $1.00 (nails) = $32.00
      assert recipe_with_cost.cost == Decimal.new(3200)
    end

    test "calculates product profit margin", %{
      product: product,
      recipe: recipe,
      material1: material1,
      material2: material2
    } do
      {:ok, _} =
        Ash.create(Catalog.RecipeMaterial, %{
          recipe_id: recipe.id,
          material_id: material1.id,
          quantity: 4
        })

      {:ok, _} =
        Ash.create(Catalog.RecipeMaterial, %{
          recipe_id: recipe.id,
          material_id: material2.id,
          quantity: 12
        })

      {:ok, product_with_margin} =
        product
        |> Ash.load!(:recipe)
        |> Ash.load(:profit_margin)

      # Sale price: $25.00
      # Cost: $32.00
      # Margin: ($25.00 - $32.00) / $32.00 = -0.21875 (negative margin)
      assert Decimal.equal?(
               product_with_margin.profit_margin,
               Decimal.from_float(-0.21875)
             )
    end
  end
end
