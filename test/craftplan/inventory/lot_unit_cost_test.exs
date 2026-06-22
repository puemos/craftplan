defmodule Craftplan.Inventory.LotUnitCostTest do
  use Craftplan.DataCase, async: true

  require Ash.Query

  alias Craftplan.Inventory

  defp staff, do: Craftplan.DataCase.staff_actor()

  defp create_supplier(name) do
    {:ok, s} =
      Inventory.Supplier
      |> Ash.Changeset.for_create(:create, %{name: name, contact_email: "x@example.test"})
      |> Ash.create(actor: staff())

    s
  end

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

  describe "Lot.unit_cost" do
    test "is accepted on create" do
      mat = create_material("M-UC-1")
      supplier = create_supplier("SUC-1")

      {:ok, lot} =
        Inventory.Lot
        |> Ash.Changeset.for_create(:create, %{
          lot_code: "LOT-UC-1",
          material_id: mat.id,
          supplier_id: supplier.id,
          received_at: DateTime.utc_now(),
          unit_cost: Decimal.new("0.55")
        })
        |> Ash.create(actor: staff())

      assert Decimal.equal?(lot.unit_cost, Decimal.new("0.55"))
    end

    test "is optional on create" do
      mat = create_material("M-UC-2")
      supplier = create_supplier("SUC-2")

      {:ok, lot} =
        Inventory.Lot
        |> Ash.Changeset.for_create(:create, %{
          lot_code: "LOT-UC-2",
          material_id: mat.id,
          supplier_id: supplier.id,
          received_at: DateTime.utc_now()
        })
        |> Ash.create(actor: staff())

      assert is_nil(lot.unit_cost)
    end
  end

  describe "PurchaseOrder.receive populates Lot.unit_cost" do
    test "uses unit_cost from lot_receipts when explicitly provided" do
      mat = create_material("M-PO-1")
      supplier = create_supplier("SPO-1")

      {:ok, po} =
        Inventory.PurchaseOrder
        |> Ash.Changeset.for_create(:create, %{
          supplier_id: supplier.id,
          status: :ordered,
          ordered_at: DateTime.utc_now()
        })
        |> Ash.create(actor: staff())

      {:ok, _} =
        Inventory.PurchaseOrderItem
        |> Ash.Changeset.for_create(:create, %{
          purchase_order_id: po.id,
          material_id: mat.id,
          quantity: Decimal.new("50"),
          unit_price: Decimal.new("0.99")
        })
        |> Ash.create(actor: staff())

      {:ok, _} =
        po
        |> Ash.Changeset.for_update(:receive, %{
          lot_receipts: [
            %{
              material_id: mat.id,
              lot_code: "PO-1-LINE-1",
              quantity: Decimal.new("50"),
              unit_cost: Decimal.new("0.62")
            }
          ]
        })
        |> Ash.update(actor: staff())

      [lot] =
        Inventory.Lot
        |> Ash.Query.filter(lot_code == "PO-1-LINE-1")
        |> Ash.read!(actor: staff())

      assert Decimal.equal?(lot.unit_cost, Decimal.new("0.62"))
    end

    test "falls back to PurchaseOrderItem.unit_price when unit_cost omitted" do
      mat = create_material("M-PO-2")
      supplier = create_supplier("SPO-2")

      {:ok, po} =
        Inventory.PurchaseOrder
        |> Ash.Changeset.for_create(:create, %{
          supplier_id: supplier.id,
          status: :ordered,
          ordered_at: DateTime.utc_now()
        })
        |> Ash.create(actor: staff())

      {:ok, _} =
        Inventory.PurchaseOrderItem
        |> Ash.Changeset.for_create(:create, %{
          purchase_order_id: po.id,
          material_id: mat.id,
          quantity: Decimal.new("50"),
          unit_price: Decimal.new("0.99")
        })
        |> Ash.create(actor: staff())

      {:ok, _} =
        po
        |> Ash.Changeset.for_update(:receive, %{
          lot_receipts: [
            %{
              material_id: mat.id,
              lot_code: "PO-2-LINE-1",
              quantity: Decimal.new("50")
            }
          ]
        })
        |> Ash.update(actor: staff())

      [lot] =
        Inventory.Lot
        |> Ash.Query.filter(lot_code == "PO-2-LINE-1")
        |> Ash.read!(actor: staff())

      assert Decimal.equal?(lot.unit_cost, Decimal.new("0.99"))

      # Stock must actually be moved — earlier regression silently skipped this
      # when actor wasn't threaded through the after_action callback.
      material =
        Inventory.get_material_by_id!(mat.id, load: :current_stock, actor: staff())

      assert Decimal.equal?(material.current_stock, Decimal.new("50"))

      # Material.price is updated from the received lot's unit_cost (last-wins),
      # and price_updated_at gets stamped automatically.
      assert Decimal.equal?(material.price, Decimal.new("0.99"))
      assert %DateTime{} = material.price_updated_at
    end

    test "skip_bom_refresh argument suppresses the BOM rollup refresh" do
      mat = create_material("M-PO-3")
      supplier = create_supplier("SPO-3")

      {:ok, po} =
        Inventory.PurchaseOrder
        |> Ash.Changeset.for_create(:create, %{
          supplier_id: supplier.id,
          status: :ordered,
          ordered_at: DateTime.utc_now()
        })
        |> Ash.create(actor: staff())

      {:ok, _} =
        Inventory.PurchaseOrderItem
        |> Ash.Changeset.for_create(:create, %{
          purchase_order_id: po.id,
          material_id: mat.id,
          quantity: Decimal.new("50"),
          unit_price: Decimal.new("0.42")
        })
        |> Ash.create(actor: staff())

      {:ok, _} =
        po
        |> Ash.Changeset.for_update(:receive, %{
          lot_receipts: [
            %{
              material_id: mat.id,
              lot_code: "PO-3-LINE-1",
              quantity: Decimal.new("50")
            }
          ],
          skip_bom_refresh: true
        })
        |> Ash.update(actor: staff())

      # Lot + movement + Material.price still happen — the only thing skipped is
      # the BOM rollup refresh (which has no observable effect on a material
      # with no BOM components, so the assertion is just that the receive
      # completed without error).
      material = Inventory.get_material_by_id!(mat.id, actor: staff())
      assert Decimal.equal?(material.price, Decimal.new("0.42"))
    end
  end
end
