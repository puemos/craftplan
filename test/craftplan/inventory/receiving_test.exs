defmodule Craftplan.Inventory.ReceivingTest do
  use Craftplan.DataCase, async: true

  alias Craftplan.Inventory
  alias Craftplan.Inventory.Receiving

  require Ash.Query

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

    # seed initial stock 100
    {:ok, _} =
      Inventory.adjust_stock(%{material_id: mat.id, quantity: Decimal.new(100), reason: "seed"},
        actor: actor
      )

    mat
  end

  test "receiving a PO increases stock and is idempotent" do
    mat = mk_material("Sugar", "SUG-1", :gram, "0.01")

    actor = Craftplan.DataCase.staff_actor()

    {:ok, supplier} =
      Inventory.Supplier
      |> Ash.Changeset.for_create(:create, %{
        name: "Sweet Supplies Co.",
        contact_email: "hi@sweets.test"
      })
      |> Ash.create(actor: actor)

    {:ok, po} =
      Inventory.PurchaseOrder
      |> Ash.Changeset.for_create(:create, %{
        supplier_id: supplier.id,
        status: :ordered,
        ordered_at: DateTime.utc_now()
      })
      |> Ash.create(actor: actor)

    {:ok, poi} =
      Inventory.PurchaseOrderItem
      |> Ash.Changeset.for_create(:create, %{
        purchase_order_id: po.id,
        material_id: mat.id,
        quantity: Decimal.new(50),
        unit_price: Decimal.new("1.00")
      })
      |> Ash.create(actor: actor)

    # Receive PO
    {:ok, _} =
      Receiving.receive_po(po.id,
        actor: actor,
        lot_receipts: [
          %{
            purchase_order_item_id: poi.id,
            material_id: mat.id,
            lot_code: "#{po.reference}-L1",
            supplier_lot_code: "SUGAR-SUP-2401",
            expiry_date: Date.add(Date.utc_today(), 90),
            quantity: Decimal.new(50)
          }
        ]
      )

    mat =
      Ash.load!(Inventory.get_material_by_id!(mat.id, actor: actor), :current_stock, actor: actor)

    assert mat.current_stock == Decimal.new(150)

    [lot] =
      Inventory.Lot
      |> Ash.Query.filter(material_id == ^mat.id and supplier_id == ^supplier.id)
      |> Ash.Query.load(:current_stock)
      |> Ash.read!(actor: actor)

    assert Decimal.equal?(lot.unit_cost, Decimal.new("1.00"))
    assert Decimal.equal?(lot.current_stock, Decimal.new(50))
    assert lot.supplier_lot_code == "SUGAR-SUP-2401"
    assert lot.purchase_order_item_id == poi.id

    # Idempotent second receive
    {:ok, :already_received} = Receiving.receive_po(po.id, actor: actor)

    mat =
      Ash.load!(Inventory.get_material_by_id!(mat.id, actor: actor), :current_stock, actor: actor)

    assert mat.current_stock == Decimal.new(150)
  end

  test "supports split and partial deliveries, prevents over-receipt, and closes the PO at the exact total" do
    actor = Craftplan.DataCase.staff_actor()
    material = mk_material("Partial Flour", "PART-FLOUR", :gram, "0.01")

    supplier =
      Inventory.Supplier
      |> Ash.Changeset.for_create(:create, %{name: "Split Delivery Mills"})
      |> Ash.create!(actor: actor)

    po =
      Inventory.PurchaseOrder
      |> Ash.Changeset.for_create(:create, %{
        supplier_id: supplier.id,
        status: :ordered,
        ordered_at: DateTime.utc_now()
      })
      |> Ash.create!(actor: actor)

    item =
      Inventory.PurchaseOrderItem
      |> Ash.Changeset.for_create(:create, %{
        purchase_order_id: po.id,
        material_id: material.id,
        quantity: Decimal.new(100),
        unit_price: Decimal.new("0.80")
      })
      |> Ash.create!(actor: actor)

    {:ok, partial_po} =
      Receiving.receive_po(po.id,
        actor: actor,
        lot_receipts: [
          %{
            purchase_order_item_id: item.id,
            material_id: material.id,
            lot_code: "#{po.reference}-L1-01",
            supplier_lot_code: "SPLIT-A",
            quantity: Decimal.new(15)
          },
          %{
            purchase_order_item_id: item.id,
            material_id: material.id,
            lot_code: "#{po.reference}-L1-02",
            supplier_lot_code: "SPLIT-B",
            quantity: Decimal.new(25)
          }
        ]
      )

    assert partial_po.status == :partially_received
    assert is_nil(partial_po.received_at)

    assert {:error, _error} =
             Receiving.receive_po(po.id,
               actor: actor,
               lot_receipts: [
                 %{
                   purchase_order_item_id: item.id,
                   material_id: material.id,
                   lot_code: "#{po.reference}-L1-03-OVER",
                   supplier_lot_code: "OVER",
                   quantity: Decimal.new(61)
                 }
               ]
             )

    {:ok, received_po} =
      Receiving.receive_po(po.id,
        actor: actor,
        lot_receipts: [
          %{
            purchase_order_item_id: item.id,
            material_id: material.id,
            lot_code: "#{po.reference}-L1-03",
            supplier_lot_code: "SPLIT-C",
            quantity: Decimal.new(60)
          }
        ]
      )

    assert received_po.status == :received
    assert received_po.received_at

    lots =
      Inventory.Lot
      |> Ash.Query.filter(purchase_order_item_id == ^item.id)
      |> Ash.Query.sort(:lot_code)
      |> Ash.read!(actor: actor)

    assert Enum.map(lots, & &1.supplier_lot_code) == ["SPLIT-A", "SPLIT-B", "SPLIT-C"]

    assert Enum.reduce(lots, Decimal.new(0), &Decimal.add(&1.received_quantity, &2)) ==
             Decimal.new(100)
  end
end
