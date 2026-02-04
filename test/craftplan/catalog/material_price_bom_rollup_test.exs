defmodule Craftplan.Catalog.MaterialPriceBomRollupTest do
  use Craftplan.DataCase, async: true

  import Ash.Expr

  alias Craftplan.Catalog.BOM
  alias Craftplan.Catalog.BOMRollup
  alias Craftplan.Catalog.Product
  alias Craftplan.Inventory.Material

  require Ash.Query

  describe "material price change refreshes BOM rollups" do
    test "price change triggers rollup refresh" do
      staff = staff_actor()

      # Create material with initial price
      material =
        Material
        |> Ash.Changeset.for_create(:create, %{
          name: "Test Material",
          sku: "MAT-001",
          unit: :gram,
          price: Decimal.new("1.00")
        })
        |> Ash.create!(actor: staff)

      # Create product with BOM using 100 units of the material
      product =
        Product
        |> Ash.Changeset.for_create(:create, %{
          name: "Test Product",
          sku: "PROD-001",
          status: :active,
          price: Decimal.new("10.00")
        })
        |> Ash.create!(actor: staff)

      _bom =
        BOM
        |> Ash.Changeset.for_create(:create, %{
          product_id: product.id,
          components: [
            %{
              component_type: :material,
              material_id: material.id,
              quantity: Decimal.new("100")
            }
          ]
        })
        |> Ash.create!(actor: staff)

      # Verify initial rollup cost is $100 (100 units * $1.00)
      rollup = get_rollup_for_product(product.id, staff)
      assert Decimal.equal?(rollup.material_cost, Decimal.new("100.00"))

      # Update material price to $2.00
      _updated_material =
        material
        |> Ash.Changeset.for_update(:update, %{price: Decimal.new("2.00")})
        |> Ash.update!(actor: staff)

      # Verify rollup cost is now $200 (100 units * $2.00)
      updated_rollup = get_rollup_for_product(product.id, staff)
      assert Decimal.equal?(updated_rollup.material_cost, Decimal.new("200.00"))
    end

    test "non-price change does not trigger rollup refresh" do
      staff = staff_actor()

      material =
        Material
        |> Ash.Changeset.for_create(:create, %{
          name: "Original Name",
          sku: "MAT-002",
          unit: :gram,
          price: Decimal.new("1.00")
        })
        |> Ash.create!(actor: staff)

      product =
        Product
        |> Ash.Changeset.for_create(:create, %{
          name: "Test Product 2",
          sku: "PROD-002",
          status: :active,
          price: Decimal.new("10.00")
        })
        |> Ash.create!(actor: staff)

      _bom =
        BOM
        |> Ash.Changeset.for_create(:create, %{
          product_id: product.id,
          components: [
            %{
              component_type: :material,
              material_id: material.id,
              quantity: Decimal.new("50")
            }
          ]
        })
        |> Ash.create!(actor: staff)

      initial_rollup = get_rollup_for_product(product.id, staff)
      initial_updated_at = initial_rollup.updated_at

      # Update material name only (not price)
      _updated_material =
        material
        |> Ash.Changeset.for_update(:update, %{name: "New Name"})
        |> Ash.update!(actor: staff)

      # Rollup should remain unchanged (same updated_at timestamp)
      unchanged_rollup = get_rollup_for_product(product.id, staff)
      assert DateTime.compare(unchanged_rollup.updated_at, initial_updated_at) == :eq
    end

    test "multiple BOMs using same material are all refreshed" do
      staff = staff_actor()

      material =
        Material
        |> Ash.Changeset.for_create(:create, %{
          name: "Shared Material",
          sku: "MAT-003",
          unit: :gram,
          price: Decimal.new("1.00")
        })
        |> Ash.create!(actor: staff)

      # Create two products with BOMs using the same material
      product1 =
        Product
        |> Ash.Changeset.for_create(:create, %{
          name: "Product A",
          sku: "PROD-003A",
          status: :active,
          price: Decimal.new("10.00")
        })
        |> Ash.create!(actor: staff)

      product2 =
        Product
        |> Ash.Changeset.for_create(:create, %{
          name: "Product B",
          sku: "PROD-003B",
          status: :active,
          price: Decimal.new("20.00")
        })
        |> Ash.create!(actor: staff)

      _bom1 =
        BOM
        |> Ash.Changeset.for_create(:create, %{
          product_id: product1.id,
          components: [
            %{component_type: :material, material_id: material.id, quantity: Decimal.new("10")}
          ]
        })
        |> Ash.create!(actor: staff)

      _bom2 =
        BOM
        |> Ash.Changeset.for_create(:create, %{
          product_id: product2.id,
          components: [
            %{component_type: :material, material_id: material.id, quantity: Decimal.new("20")}
          ]
        })
        |> Ash.create!(actor: staff)

      # Verify initial costs
      rollup1 = get_rollup_for_product(product1.id, staff)
      rollup2 = get_rollup_for_product(product2.id, staff)
      assert Decimal.equal?(rollup1.material_cost, Decimal.new("10.00"))
      assert Decimal.equal?(rollup2.material_cost, Decimal.new("20.00"))

      # Update material price
      _updated_material =
        material
        |> Ash.Changeset.for_update(:update, %{price: Decimal.new("3.00")})
        |> Ash.update!(actor: staff)

      # Both rollups should be updated
      updated_rollup1 = get_rollup_for_product(product1.id, staff)
      updated_rollup2 = get_rollup_for_product(product2.id, staff)
      assert Decimal.equal?(updated_rollup1.material_cost, Decimal.new("30.00"))
      assert Decimal.equal?(updated_rollup2.material_cost, Decimal.new("60.00"))
    end

    test "material not used in any BOM handles gracefully" do
      staff = staff_actor()

      material =
        Material
        |> Ash.Changeset.for_create(:create, %{
          name: "Unused Material",
          sku: "MAT-004",
          unit: :gram,
          price: Decimal.new("1.00")
        })
        |> Ash.create!(actor: staff)

      # Update price - should not raise even though no BOMs use this material
      updated_material =
        material
        |> Ash.Changeset.for_update(:update, %{price: Decimal.new("5.00")})
        |> Ash.update!(actor: staff)

      assert Decimal.equal?(updated_material.price, Decimal.new("5.00"))
    end
  end

  defp get_rollup_for_product(product_id, actor) do
    BOMRollup
    |> Ash.Query.new()
    |> Ash.Query.filter(expr(product_id == ^product_id))
    |> Ash.read_one!(actor: actor, authorize?: false)
  end
end
