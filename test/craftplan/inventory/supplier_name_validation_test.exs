defmodule Craftplan.Inventory.SupplierNameValidationTest do
  use Craftplan.DataCase, async: true

  alias Craftplan.Inventory.Supplier

  defp staff, do: Craftplan.DataCase.staff_actor()

  defp create_supplier(name, contact_name \\ nil) do
    params = %{name: name}
    params = if contact_name, do: Map.put(params, :contact_name, contact_name), else: params

    Supplier
    |> Ash.Changeset.for_create(:create, params)
    |> Ash.create(actor: staff())
  end

  describe "supplier name validation" do
    test "accepts ASCII name" do
      assert {:ok, _} = create_supplier("ACME Supplies")
    end

    test "accepts Japanese name" do
      assert {:ok, _} = create_supplier("東京食材株式会社")
    end

    test "rejects invalid chars" do
      assert {:error, changeset} = create_supplier("ACME@Supplies")
      assert inspect(changeset.errors) =~ "must match"
    end
  end

  describe "supplier contact_name validation" do
    test "accepts Japanese contact name" do
      assert {:ok, _} = create_supplier("Supplier A", "田中太郎")
    end

    test "rejects invalid chars in contact name" do
      assert {:error, changeset} = create_supplier("Supplier B", "John#Doe")
      assert inspect(changeset.errors) =~ "must match"
    end
  end
end
