defmodule Craftplan.Inventory.MaterialArchiveTest do
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

  describe "archive / unarchive" do
    test "archive sets archived_at; unarchive clears it" do
      mat = create_material("ARCH-1")
      assert is_nil(mat.archived_at)

      {:ok, archived} = Inventory.archive_material(mat, actor: staff())
      assert %DateTime{} = archived.archived_at

      {:ok, restored} = Inventory.unarchive_material(archived, actor: staff())
      assert is_nil(restored.archived_at)
    end
  end

  describe "list_materials default" do
    test "excludes archived materials" do
      active = create_material("ARCH-LIST-ACTIVE")
      archived_seed = create_material("ARCH-LIST-ARCHIVED")
      {:ok, _} = Inventory.archive_material(archived_seed, actor: staff())

      results = Inventory.list_materials!(actor: staff())
      ids = Enum.map(results, & &1.id)

      assert active.id in ids
      refute archived_seed.id in ids
    end

    test "include_archived: true returns all" do
      active = create_material("ARCH-LIST-ACTIVE-2")
      archived_seed = create_material("ARCH-LIST-ARCHIVED-2")
      {:ok, _} = Inventory.archive_material(archived_seed, actor: staff())

      results =
        Inventory.list_materials!(%{include_archived: true}, actor: staff())

      ids = Enum.map(results, & &1.id)

      assert active.id in ids
      assert archived_seed.id in ids
    end
  end

  describe "preservation guarantees" do
    test "archiving does not touch movements or lots" do
      mat = create_material("ARCH-PRESERVE")

      {:ok, _} =
        Inventory.adjust_stock(
          %{material_id: mat.id, quantity: Decimal.new(10), reason: "seed"},
          actor: staff()
        )

      {:ok, _} = Inventory.archive_material(mat, actor: staff())

      with_stock =
        Inventory.get_material_by_id!(mat.id, load: :current_stock, actor: staff())

      assert Decimal.equal?(with_stock.current_stock, Decimal.new(10))
    end
  end
end
