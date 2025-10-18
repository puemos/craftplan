defmodule Craftplan.Inventory.OpenPOsForMaterialTest do
  use Craftplan.DataCase, async: true

  alias Craftplan.Inventory

  defp mk_supplier(name) do
    actor = Craftplan.DataCase.staff_actor()

    {:ok, s} =
      Inventory.Supplier
      |> Ash.Changeset.for_create(:create, %{name: name})
      |> Ash.create(actor: actor)

    s
  end

  defp mk_material(name, sku, unit, price) do
    actor = Craftplan.DataCase.staff_actor()

    {:ok, mat} =
      Inventory.Material
      |> Ash.Changeset.for_create(:create, %{
        name: name,
        sku: sku,
        unit: unit,
        price: Decimal.new(price)
      })
      |> Ash.create(actor: actor)

    mat
  end

  test "lists open PO items for a material and excludes received" do
    mat = mk_material("Flour", "F-PO", :gram, "0.01")
    s = mk_supplier("ACME")

    actor = Craftplan.DataCase.staff_actor()

    {:ok, po} =
      Inventory.PurchaseOrder
      |> Ash.Changeset.for_create(:create, %{supplier_id: s.id, status: :ordered})
      |> Ash.create(actor: actor)

    {:ok, _poi} =
      Inventory.PurchaseOrderItem
      |> Ash.Changeset.for_create(:create, %{
        purchase_order_id: po.id,
        material_id: mat.id,
        quantity: Decimal.new(10)
      })
      |> Ash.create(actor: actor)

    list = Inventory.list_open_po_items_for_material!(%{material_id: mat.id}, actor: actor)
    assert length(list) == 1

    # Mark PO received -> should disappear from open list
    {:ok, _} =
      po
      |> Ash.Changeset.for_update(:update, %{status: :received, received_at: DateTime.utc_now()})
      |> Ash.update(actor: actor)

    list2 = Inventory.list_open_po_items_for_material!(%{material_id: mat.id}, actor: actor)
    assert list2 == []
  end
end
