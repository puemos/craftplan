defmodule Craftplan.CSV.ProductsImporterTest do
  use Craftplan.DataCase, async: true

  alias Craftplan.CSV.Importers.Products
  alias Craftplan.Catalog

  describe "dry_run/2" do
    test "returns errors on invalid rows and no rows on failure" do
      csv = "name,sku,price\nBad,BAD,xxx\n"
      assert {:ok, %{rows: rows, errors: errors}} = Products.dry_run(csv, delimiter: ",", mapping: %{})
      assert rows == []
      assert length(errors) == 1
      assert Enum.any?(errors, &String.contains?(&1.message, "Invalid price"))
    end
  end

  describe "import/2" do
    test "inserts new products and updates existing ones" do
      actor = Craftplan.DataCase.staff_actor()

      csv1 = "name,sku,price\nProd A,PA-1,1.00\nProd B,PB-2,2.50\n"
      assert {:ok, %{inserted: 2, updated: 0, errors: []}} = Products.import(csv1, delimiter: ",", mapping: %{}, actor: actor)

      # Verify created
      assert {:ok, _} = Catalog.get_product_by_sku("PA-1", actor: actor)
      assert {:ok, _} = Catalog.get_product_by_sku("PB-2", actor: actor)

      # Update one
      csv2 = "name,sku,price\nProd A v2,PA-1,1.25\nProd B,PB-2,2.50\n"
      assert {:ok, %{inserted: 0, updated: updated, errors: []}} = Products.import(csv2, delimiter: ",", mapping: %{}, actor: actor)
      assert updated >= 1
    end
  end
end
