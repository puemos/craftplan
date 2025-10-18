defmodule Craftplan.CSV.MaterialsImporterTest do
  use Craftplan.DataCase, async: true

  alias Craftplan.CSV.Importers.Materials
  alias Craftplan.Inventory

  describe "dry_run/2" do
    test "returns error for invalid unit" do
      csv = "name,sku,unit,price\nFlour,FLR-1,unknown,1.0\n"
      assert {:ok, %{rows: [], errors: errors}} = Materials.dry_run(csv, delimiter: ",", mapping: %{})
      assert Enum.any?(errors, &String.contains?(&1.message, "Invalid unit"))
    end
  end

  describe "import/2" do
    test "inserts or updates materials by sku" do
      actor = Craftplan.DataCase.staff_actor()

      csv1 = "name,sku,unit,price\nFlour,FLR-1,g,1.00\nMilk,MLK-1,ml,0.50\n"
      assert {:ok, %{inserted: 2, updated: 0, errors: []}} = Materials.import(csv1, delimiter: ",", mapping: %{}, actor: actor)

      assert {:ok, _} = Inventory.get_material_by_sku("FLR-1", actor: actor)
      assert {:ok, _} = Inventory.get_material_by_sku("MLK-1", actor: actor)

      # Update one
      csv2 = "name,sku,unit,price\nFlour Premium,FLR-1,g,1.20\n"
      assert {:ok, %{inserted: 0, updated: updated, errors: []}} = Materials.import(csv2, delimiter: ",", mapping: %{}, actor: actor)
      assert updated >= 1
    end
  end
end

