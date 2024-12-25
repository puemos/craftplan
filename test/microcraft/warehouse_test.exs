defmodule Microcraft.WarehouseTest do
  use Microcraft.DataCase
  alias Microcraft.Warehouse

  require Ash.Query

  describe "materials" do
    @valid_attrs %{
      name: "Wood",
      sku: "WD-001",
      unit: :piece,
      price: Decimal.new(500),
      minimum_stock: Decimal.new(10),
      maximum_stock: Decimal.new(100)
    }

    test "creates material with valid attributes" do
      assert {:ok, material} =
               Ash.Changeset.for_create(Warehouse.Material, :create, @valid_attrs)
               |> Ash.create()

      assert material.name == "Wood"
      assert material.sku == "WD-001"
      assert material.unit == :piece
      assert Decimal.equal?(material.price, Decimal.new(500))
      assert Decimal.equal?(material.minimum_stock, Decimal.new(10))
      assert Decimal.equal?(material.maximum_stock, Decimal.new(100))
    end

    test "prevents duplicate SKUs" do
      assert {:ok, _material} =
               Ash.Changeset.for_create(Warehouse.Material, :create, @valid_attrs)
               |> Ash.create()

      assert {:error, _changeset} =
               Ash.Changeset.for_create(Warehouse.Material, :create, %{
                 @valid_attrs
                 | name: "Different Wood"
               })
               |> Ash.create()
    end

    test "prevents invalid units" do
      assert {:error,
              %Ash.Error.Invalid{errors: [%Ash.Error.Changes.InvalidAttribute{field: :unit}]}} =
               Ash.Changeset.for_create(Warehouse.Material, :create, %{
                 @valid_attrs
                 | unit: :invalid_unit
               })
               |> Ash.create()
    end

    test "requires valid stock limits" do
      assert {:error, _changeset} =
               Ash.Changeset.for_create(Warehouse.Material, :create, %{
                 @valid_attrs
                 | minimum_stock: Decimal.new(-10)
               })
               |> Ash.create()

      assert {:error, _changeset} =
               Ash.Changeset.for_create(Warehouse.Material, :create, %{
                 @valid_attrs
                 | maximum_stock: Decimal.new(-100)
               })
               |> Ash.create()
    end
  end

  describe "movements and aggregates" do
    setup do
      {:ok, material} =
        Ash.Changeset.for_create(Warehouse.Material, :create, %{
          name: "Wood",
          sku: "WD-001",
          unit: :piece,
          price: Decimal.new(500),
          minimum_stock: Decimal.new(10),
          maximum_stock: Decimal.new(100)
        })
        |> Ash.create()

      %{material: material}
    end

    test "calculates current stock aggregate", %{material: material} do
      # Create movements
      {:ok, _movement1} =
        Ash.Changeset.for_create(
          Warehouse.Movement,
          :adjust_stock,
          %{
            material_id: material.id,
            quantity: Decimal.new(50),
            reason: "Initial stock"
          }
        )
        |> Ash.create()

      {:ok, _movement2} =
        Ash.Changeset.for_create(
          Warehouse.Movement,
          :adjust_stock,
          %{
            material_id: material.id,
            quantity: Decimal.new(-20),
            reason: "Usage"
          }
        )
        |> Ash.create()

      # Load and verify current stock
      material =
        Warehouse.Material
        |> Ash.Query.load(:current_stock)
        |> Ash.Query.filter(id == ^material.id)
        |> Ash.read_one!()

      assert Decimal.equal?(material.current_stock, Decimal.new(30))
    end

    test "ensures current stock updates after new movements", %{material: material} do
      # Create an initial movement
      {:ok, _movement1} =
        Ash.Changeset.for_create(
          Warehouse.Movement,
          :adjust_stock,
          %{
            material_id: material.id,
            quantity: Decimal.new(50),
            reason: "Initial stock"
          }
        )
        |> Ash.create()

      # Reload material and check stock
      material =
        Warehouse.Material
        |> Ash.Query.load(:current_stock)
        |> Ash.Query.filter(id == ^material.id)
        |> Ash.read_one!()

      assert Decimal.equal?(material.current_stock, Decimal.new(50))

      # Add another movement
      {:ok, _movement2} =
        Ash.Changeset.for_create(
          Warehouse.Movement,
          :adjust_stock,
          %{
            material_id: material.id,
            quantity: Decimal.new(-10),
            reason: "Usage"
          }
        )
        |> Ash.create()

      # Reload material again
      material =
        Warehouse.Material
        |> Ash.Query.load(:current_stock)
        |> Ash.Query.filter(id == ^material.id)
        |> Ash.read_one!()

      assert Decimal.equal?(material.current_stock, Decimal.new(40))
    end
  end
end
