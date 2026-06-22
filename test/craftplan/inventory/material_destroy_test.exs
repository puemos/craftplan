defmodule Craftplan.Inventory.MaterialDestroyTest do
  use Craftplan.DataCase, async: true

  alias Craftplan.Inventory

  defp staff, do: Craftplan.DataCase.staff_actor()

  defp create_material(sku) do
    {:ok, m} =
      Inventory.Material
      |> Ash.Changeset.for_create(:create, %{
        name: "Test #{sku}",
        sku: sku,
        unit: :gram,
        price: Decimal.new("1.00")
      })
      |> Ash.create(actor: staff())

    m
  end

  defp create_supplier(name) do
    {:ok, s} =
      Inventory.Supplier
      |> Ash.Changeset.for_create(:create, %{name: name, contact_email: "x@example.test"})
      |> Ash.create(actor: staff())

    s
  end

  describe "Material destroy" do
    test "destroys cleanly when no history exists" do
      mat = create_material("DESTROY-1")
      assert :ok = Ash.destroy(mat, actor: staff())
    end

    test "refuses with a clear message when movements exist" do
      mat = create_material("DESTROY-2")

      {:ok, _} =
        Inventory.adjust_stock(
          %{material_id: mat.id, quantity: Decimal.new(10), reason: "seed"},
          actor: staff()
        )

      assert {:error, error} = Ash.destroy(mat, actor: staff())
      assert error_message(error) =~ "Cannot delete"
      assert error_message(error) =~ "movement"
    end

    test "refuses with a clear message when lots exist" do
      mat = create_material("DESTROY-3")
      supplier = create_supplier("DSUP-1")

      {:ok, _} =
        Inventory.Lot
        |> Ash.Changeset.for_create(:create, %{
          lot_code: "LOT-DESTROY-#{System.unique_integer([:positive])}",
          material_id: mat.id,
          supplier_id: supplier.id,
          received_at: DateTime.utc_now()
        })
        |> Ash.create(actor: staff())

      assert {:error, error} = Ash.destroy(mat, actor: staff())
      assert error_message(error) =~ "Cannot delete"
      assert error_message(error) =~ "lot"
    end
  end

  defp error_message(%Ash.Error.Invalid{errors: errors}) do
    errors
    |> Enum.map(fn
      %{message: msg} when is_binary(msg) -> msg
      other -> inspect(other)
    end)
    |> Enum.join(" | ")
  end
end
