defmodule Craftplan.Inventory.ReceivingTest do
  use Craftplan.DataCase, async: true

  alias Craftplan.Inventory
  alias Craftplan.Inventory.Receiving

  defp mk_material(name, sku, unit, price) do
    actor = Craftplan.DataCase.staff_actor()

    {:ok, mat} =
      Inventory.Material
      |> Ash.Changeset.for_create(:create, %{
        name: name,
        sku: sku,
        unit: unit,
        price: Money.new(price, :USD)
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

    {:ok, _poi} =
      Inventory.PurchaseOrderItem
      |> Ash.Changeset.for_create(:create, %{
        purchase_order_id: po.id,
        material_id: mat.id,
        quantity: Decimal.new(50),
        unit_price: Money.new("1.00", :USD)
      })
      |> Ash.create(actor: actor)

    # Receive PO
    {:ok, _} = Receiving.receive_po(po.id, actor: actor)

    mat =
      Ash.load!(Inventory.get_material_by_id!(mat.id, actor: actor), :current_stock, actor: actor)

    assert mat.current_stock == Decimal.new(150)

    # Idempotent second receive
    {:ok, :already_received} = Receiving.receive_po(po.id, actor: actor)

    mat =
      Ash.load!(Inventory.get_material_by_id!(mat.id, actor: actor), :current_stock, actor: actor)

    assert mat.current_stock == Decimal.new(150)
  end
end
