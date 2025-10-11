defmodule Craftday.Inventory.ReceivingTest do
  use Craftday.DataCase, async: true

  alias Craftday.Inventory
  alias Craftday.Inventory.Receiving

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

    # seed initial stock 100
    {:ok, _} =
      Inventory.adjust_stock(%{material_id: mat.id, quantity: Decimal.new(100), reason: "seed"})

    mat
  end

  test "receiving a PO increases stock and is idempotent" do
    mat = mk_material("Sugar", "SUG-1", :gram, "0.01")

    {:ok, supplier} =
      Inventory.Supplier
      |> Ash.Changeset.for_create(:create, %{
        name: "Sweet Supplies Co.",
        contact_email: "hi@sweets.test"
      })
      |> Ash.create()

    {:ok, po} =
      Inventory.PurchaseOrder
      |> Ash.Changeset.for_create(:create, %{
        supplier_id: supplier.id,
        status: :ordered,
        ordered_at: DateTime.utc_now()
      })
      |> Ash.create()

    {:ok, _poi} =
      Inventory.PurchaseOrderItem
      |> Ash.Changeset.for_create(:create, %{
        purchase_order_id: po.id,
        material_id: mat.id,
        quantity: Decimal.new(50),
        unit_price: Decimal.new("1.00")
      })
      |> Ash.create()

    # Receive PO
    {:ok, _} = Receiving.receive_po(po.id)
    mat = Ash.load!(Inventory.get_material_by_id!(mat.id), :current_stock)
    assert mat.current_stock == Decimal.new(150)

    # Idempotent second receive
    {:ok, :already_received} = Receiving.receive_po(po.id)
    mat = Ash.load!(Inventory.get_material_by_id!(mat.id), :current_stock)
    assert mat.current_stock == Decimal.new(150)
  end
end
