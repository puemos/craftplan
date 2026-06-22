defmodule Craftplan.Inventory.CorrectiveAdjustmentTest do
  @moduledoc """
  Movements are append-only. A "corrective adjustment" is just a new movement
  with the opposite sign and a reason that references the original. The UI
  helper that pre-fills the form is in CraftplanWeb; this test exercises the
  underlying Inventory.adjust_stock behaviour that the helper composes.
  """
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

  describe "corrective adjustment workflow" do
    test "negating an erroneous receipt brings stock back to the prior value" do
      mat = create_material("CORR-1")

      # Original receipt: claimed 100 g but it should have been 80 g
      {:ok, _receipt} =
        Inventory.adjust_stock(
          %{material_id: mat.id, quantity: Decimal.new(100), reason: "PO foo receive"},
          actor: staff()
        )

      assert stock(mat) == Decimal.new(100)

      # Corrective adjustment: subtract 20 g with a reason referencing the original
      {:ok, _correction} =
        Inventory.adjust_stock(
          %{
            material_id: mat.id,
            quantity: Decimal.new(-20),
            reason: "Correction of 'PO foo receive' on 2026-06-16: physical count short by 20g"
          },
          actor: staff()
        )

      assert stock(mat) == Decimal.new(80)

      # Both movements are preserved — the corrective approach never deletes
      movements =
        Inventory.list_movements!(actor: staff())
        |> Enum.filter(&(&1.material_id == mat.id))

      assert length(movements) == 2
    end

    test "fully reversing a movement nets to zero quantity but preserves both records" do
      mat = create_material("CORR-2")

      {:ok, _original} =
        Inventory.adjust_stock(
          %{material_id: mat.id, quantity: Decimal.new(50), reason: "ingested twice by mistake"},
          actor: staff()
        )

      {:ok, _reverse} =
        Inventory.adjust_stock(
          %{
            material_id: mat.id,
            quantity: Decimal.new(-50),
            reason: "Correction of 'ingested twice by mistake': full reversal"
          },
          actor: staff()
        )

      assert stock(mat) == Decimal.new(0)

      movements =
        Inventory.list_movements!(actor: staff())
        |> Enum.filter(&(&1.material_id == mat.id))

      assert length(movements) == 2
    end
  end

  defp stock(mat) do
    Inventory.get_material_by_id!(mat.id, load: :current_stock, actor: staff()).current_stock
  end
end
