defmodule CraftplanWeb.ProductionBatchLiveTest do
  use CraftplanWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Ash.Changeset
  alias Craftplan.Inventory
  alias Craftplan.Orders.OrderItemLot
  alias Craftplan.Test.Factory
  alias Decimal, as: D

  @tag role: :staff
  test "renders batch show page when items linked via allocations (no batch_code on item)", %{
    conn: conn,
    user: user
  } do
    actor = user

    product =
      Factory.create_product!(
        %{name: "Alloc Bread", sku: "alloc-bread", price: D.new("12.00")},
        actor
      )

    material =
      Factory.create_material!(%{name: "Alloc Flour", unit: :gram, price: D.new("3.00")}, actor)

    Factory.create_recipe!(product, [%{material_id: material.id, quantity: D.new("1.0")}], actor)

    customer = Factory.create_customer!()

    order =
      Factory.create_order_with_items!(
        customer,
        [%{product_id: product.id, quantity: D.new("8"), unit_price: D.new("15.00")}],
        actor: actor
      )

    item = hd(order.items)

    # Create batch via open_with_allocations (new flow — no batch_code on item)
    {:ok, batch} =
      Craftplan.Orders.ProductionBatch
      |> Changeset.for_create(:open_with_allocations, %{
        product_id: product.id,
        planned_qty: D.new("8"),
        allocations: [%{order_item_id: item.id, planned_qty: D.new("8")}]
      })
      |> Ash.create(actor: actor)

    {:ok, _view, html} = live(conn, ~p"/manage/production/batches/#{batch.batch_code}")

    assert html =~ batch.batch_code
    assert html =~ "Alloc Bread"
  end

  @tag role: :staff
  test "renders batch summary and allocations", %{conn: conn, user: user} do
    actor = user

    product =
      Factory.create_product!(
        %{name: "Batch Bread", sku: "batch-bread", price: D.new("12.00")},
        actor
      )

    material =
      Factory.create_material!(%{name: "Flour", unit: :gram, price: D.new("3.00")}, actor)

    Factory.create_recipe!(product, [%{material_id: material.id, quantity: D.new("1.0")}], actor)

    customer = Factory.create_customer!()

    order =
      Factory.create_order_with_items!(
        customer,
        [
          %{product_id: product.id, quantity: D.new("5"), unit_price: D.new("15.00")}
        ],
        actor: actor
      )

    item = hd(order.items)

    # Create a production batch and assign the item to it
    {:ok, batch} =
      Craftplan.Orders.ProductionBatch
      |> Changeset.for_create(:open, %{
        product_id: product.id,
        planned_qty: D.new("5")
      })
      |> Ash.create(actor: actor)

    # Force-assign the batch_code on the item
    item =
      item
      |> Changeset.for_update(:update, %{status: :done})
      |> Changeset.force_change_attribute(:batch_code, batch.batch_code)
      |> Changeset.force_change_attribute(:production_batch_id, batch.id)
      |> Ash.update!(actor: actor)

    {:ok, lot} =
      Inventory.Lot
      |> Changeset.for_create(:create, %{
        lot_code: "LOT-TEST",
        material_id: material.id,
        expiry_date: Date.add(Date.utc_today(), 14),
        received_at: DateTime.utc_now()
      })
      |> Ash.create(actor: actor)

    _ =
      Inventory.Movement
      |> Changeset.for_create(:adjust_stock, %{
        material_id: material.id,
        lot_id: lot.id,
        quantity: D.new("20"),
        reason: "Test receipt"
      })
      |> Ash.create!(actor: actor)

    _ =
      OrderItemLot
      |> Changeset.for_create(:create, %{
        order_item_id: item.id,
        lot_id: lot.id,
        quantity_used: D.new("5")
      })
      |> Ash.create!(actor: actor)

    {:ok, view, html} = live(conn, ~p"/manage/production/batches/#{batch.batch_code}")

    assert html =~ batch.batch_code
    assert has_element?(view, "#batch-orders-table")
    assert has_element?(view, "#batch-lots-table")
    assert has_element?(view, "#batch-lots-table td", "LOT-TEST")
  end
end
