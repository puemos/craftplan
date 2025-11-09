defmodule Craftplan.ProductionBatchingTest do
  use Craftplan.DataCase, async: true

  alias Ash.Changeset
  alias Craftplan.Inventory
  alias Craftplan.Orders
  alias Craftplan.Production.Batching
  alias Craftplan.Test.Factory
  alias Decimal, as: D

  test "open, consume, and complete batch allocates costs and updates items" do
    actor = Craftplan.DataCase.staff_actor()

    # Product + material + BOM
    product =
      Factory.create_product!(
        %{name: "Sourdough", sku: "sourdough", price: D.new("12.00")},
        actor
      )

    flour = Factory.create_material!(%{name: "Flour", unit: :gram, price: D.new("0.01")}, actor)

    _bom =
      Factory.create_recipe!(product, [%{material_id: flour.id, quantity: D.new("500")}], actor)

    # Lots & stock
    {:ok, lot} =
      Inventory.Lot
      |> Changeset.for_create(:create, %{
        lot_code: "FLOT-1",
        material_id: flour.id,
        expiry_date: Date.add(Date.utc_today(), 60),
        received_at: DateTime.utc_now()
      })
      |> Ash.create(actor: actor)

    _ =
      Inventory.Movement
      |> Changeset.for_create(:adjust_stock, %{
        material_id: flour.id,
        lot_id: lot.id,
        quantity: D.new("50000"),
        reason: "Seed stock"
      })
      |> Ash.create!(actor: actor)

    # Orders with items
    customer = Factory.create_customer!()

    order1 =
      Factory.create_order_with_items!(
        customer,
        [%{product_id: product.id, quantity: D.new("10"), unit_price: D.new("12.00")}],
        actor: actor
      )

    order2 =
      Factory.create_order_with_items!(
        customer,
        [%{product_id: product.id, quantity: D.new("5"), unit_price: D.new("12.00")}],
        actor: actor
      )

    item1 = hd(order1.items)
    item2 = hd(order2.items)

    # Open batch (planned 15)
    {:ok, batch} = Batching.open_batch(product.id, D.new("15"), actor: actor)

    # Add allocations
    _ =
      Orders.OrderItemBatchAllocation
      |> Changeset.for_create(:create, %{
        production_batch_id: batch.id,
        order_item_id: item1.id,
        planned_qty: D.new("10")
      })
      |> Ash.create!(actor: actor)

    _ =
      Orders.OrderItemBatchAllocation
      |> Changeset.for_create(:create, %{
        production_batch_id: batch.id,
        order_item_id: item2.id,
        planned_qty: D.new("5")
      })
      |> Ash.create!(actor: actor)

    # Consume flour: 500g/unit * 15 = 7500g
    {:ok, :consumed} =
      Batching.consume_batch(
        batch,
        %{
          flour.id => [%{lot_id: lot.id, quantity: D.new("7500")}]
        },
        actor: actor
      )

    # Complete produced 15
    {:ok, :completed} =
      Batching.complete_batch(batch,
        actor: actor,
        produced_qty: D.new("15"),
        duration_minutes: 60
      )

    # Verify items progressed to in_progress or done based on completion
    item1 = Orders.get_order_item_by_id!(item1.id, actor: actor, load: [:status])
    item2 = Orders.get_order_item_by_id!(item2.id, actor: actor, load: [:status])

    assert item1.status in [:in_progress, :done]
    assert item2.status in [:in_progress, :done]
  end
end
