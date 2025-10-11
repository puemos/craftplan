defmodule Craftday.Inventory.OpenPOsForMaterialTest do
  use Craftday.DataCase, async: true

  alias Craftday.Inventory

  defp mk_supplier(name) do
    {:ok, s} =
      Inventory.Supplier
      |> Ash.Changeset.for_create(:create, %{name: name})
      |> Ash.create()

    s
  end

  defp mk_material(name, sku, unit, price) do
    {:ok, mat} =
      Inventory.Material
      |> Ash.Changeset.for_create(:create, %{
        name: name,
        sku: sku,
        unit: unit,
        price: Decimal.new(price)
      })
      |> Ash.create()

    mat
  end

  test "lists open PO items for a material and excludes received" do
    mat = mk_material("Flour", "F-PO", :gram, "0.01")
    s = mk_supplier("ACME")

    {:ok, po} =
      Inventory.PurchaseOrder
      |> Ash.Changeset.for_create(:create, %{supplier_id: s.id, status: :ordered})
      |> Ash.create()

    {:ok, _poi} =
      Inventory.PurchaseOrderItem
      |> Ash.Changeset.for_create(:create, %{
        purchase_order_id: po.id,
        material_id: mat.id,
        quantity: Decimal.new(10)
      })
      |> Ash.create()

    list = Inventory.list_open_po_items_for_material!(%{material_id: mat.id})
    assert length(list) == 1

    # Mark PO received -> should disappear from open list
    {:ok, _} =
      po
      |> Ash.Changeset.for_update(:update, %{status: :received, received_at: DateTime.utc_now()})
      |> Ash.update()

    list2 = Inventory.list_open_po_items_for_material!(%{material_id: mat.id})
    assert list2 == []
  end
end
