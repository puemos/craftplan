defmodule Craftplan.CSV.CustomersImporterTest do
  use Craftplan.DataCase, async: true

  alias Craftplan.CSV.Importers.Customers
  alias Craftplan.CRM

  describe "dry_run/2" do
    test "flags invalid email" do
      csv = "type,first_name,last_name,email\nindividual,Jane,Doe,invalid\n"
      assert {:ok, %{rows: [], errors: errors}} = Customers.dry_run(csv, delimiter: ",", mapping: %{})
      assert Enum.any?(errors, &String.contains?(&1.message, "Invalid email"))
    end
  end

  describe "import/2" do
    test "inserts and updates customers by email" do
      actor = Craftplan.DataCase.staff_actor()

      csv = "type,first_name,last_name,email\nindividual,Jane,Doe,jane@example.com\n"
      assert {:ok, %{inserted: 1, updated: 0, errors: []}} = Customers.import(csv, delimiter: ",", mapping: %{}, actor: actor)

      assert {:ok, _} = CRM.get_customer_by_email("jane@example.com", actor: actor)

      csv2 = "type,first_name,last_name,email\nindividual,Janet,Doe,jane@example.com\n"
      assert {:ok, %{inserted: 0, updated: updated, errors: []}} = Customers.import(csv2, delimiter: ",", mapping: %{}, actor: actor)
      assert updated >= 1
    end
  end
end
