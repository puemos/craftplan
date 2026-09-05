defmodule CraftplanWeb.TraceabilityLiveTest do
  use CraftplanWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Ash.Changeset
  alias Craftplan.CRM.Customer
  alias Craftplan.Inventory
  alias Craftplan.Inventory.Receiving
  alias Craftplan.Orders
  alias Craftplan.Production.Batching
  alias Craftplan.Test.Factory
  alias Decimal, as: D

  @tag role: :staff
  test "traces a supplier lot forward and each split batch backward without cross-contamination",
       %{
         conn: conn,
         user: actor
       } do
    product =
      Factory.create_product!(
        %{name: "Trace Bread", sku: "trace-bread-#{System.unique_integer([:positive])}"},
        actor
      )

    flour =
      Factory.create_material!(
        %{name: "Trace Flour", sku: "trace-flour-#{System.unique_integer([:positive])}"},
        actor
      )

    bom =
      Factory.create_recipe!(product, [%{material_id: flour.id, quantity: D.new("100")}], actor)

    bom
    |> Changeset.for_update(:promote, %{})
    |> Ash.update!(actor: actor)

    supplier =
      Inventory.create_supplier!(
        %{
          name: "Trace Mills",
          address: %{street: "1 Grain Road", city: "Parma", country: "IT"}
        },
        actor: actor
      )

    po =
      Inventory.create_purchase_order!(
        %{supplier_id: supplier.id, ordered_at: DateTime.utc_now()},
        actor: actor
      )

    po_item =
      Inventory.create_purchase_order_item!(
        %{
          purchase_order_id: po.id,
          material_id: flour.id,
          quantity: D.new("1000"),
          unit_price: D.new("0.01")
        },
        actor: actor
      )

    {:ok, _} =
      Receiving.receive_po(po.id,
        actor: actor,
        lot_receipts: [
          %{
            purchase_order_item_id: po_item.id,
            material_id: flour.id,
            lot_code: "#{po.reference}-L1",
            supplier_lot_code: "MILL-LOT-2026-77",
            quantity: D.new("1000")
          }
        ]
      )

    [lot_one] = Inventory.list_lots!(actor: actor)

    lot_two =
      Inventory.Lot
      |> Changeset.for_create(:create, %{
        lot_code: "SECOND-INTERNAL-LOT",
        supplier_lot_code: "MILL-LOT-2026-88",
        material_id: flour.id,
        supplier_id: supplier.id,
        received_at: DateTime.utc_now()
      })
      |> Ash.create!(actor: actor)

    Inventory.adjust_stock!(
      %{
        material_id: flour.id,
        lot_id: lot_two.id,
        quantity: D.new("1000"),
        reason: "Second trace lot"
      },
      actor: actor
    )

    customer =
      Customer
      |> Changeset.for_create(:create, %{
        type: :company,
        first_name: "Recall",
        last_name: "Customer",
        email: "recall@example.test",
        shipping_address: %{street: "8 Market Street", city: "Rome", country: "IT"}
      })
      |> Ash.create!()

    order =
      Factory.create_order_with_items!(
        customer,
        [%{product_id: product.id, quantity: D.new("10"), unit_price: D.new("5")}],
        actor: actor
      )

    item = hd(order.items)
    batch_one = completed_batch(product, item, lot_one, flour, "5", actor)
    batch_two = completed_batch(product, item, lot_two, flour, "5", actor)

    {:ok, forward_view, _html} =
      live(conn, ~p"/manage/production/traceability?q=MILL-LOT-2026-77")

    assert has_element?(forward_view, "#ingredient-lot-#{lot_one.id}", "MILL-LOT-2026-77")
    assert has_element?(forward_view, "#trace-orders-#{batch_one.id}", "Recall Customer")
    assert has_element?(forward_view, "#recall-command")
    assert has_element?(forward_view, "#trace-chain-#{lot_one.id}")
    assert render(forward_view) =~ batch_one.batch_code
    refute has_element?(forward_view, "#ingredient-lot-#{lot_one.id}", batch_two.batch_code)

    forward_view
    |> element("#hold-lot-#{lot_one.id}")
    |> render_click()

    assert has_element?(forward_view, "#release-lot-#{lot_one.id}")

    available_lots =
      Inventory.list_available_lots_for_material!(%{material_id: flour.id}, actor: actor)

    refute Enum.any?(available_lots, &(&1.id == lot_one.id))

    csv_conn =
      get(conn, ~p"/manage/production/traceability/export.csv?mode=forward&q=MILL-LOT-2026-77")

    assert response(csv_conn, 200) =~ "MILL-LOT-2026-77"
    assert get_resp_header(csv_conn, "content-type") == ["text/csv; charset=utf-8"]

    {:ok, backward_view, _html} =
      live(conn, ~p"/manage/production/traceability?q=#{batch_two.batch_code}")

    assert has_element?(backward_view, "#finished-batch-#{batch_two.id}", batch_two.batch_code)
    assert render(backward_view) =~ "MILL-LOT-2026-88"
    refute has_element?(backward_view, "#trace-lots-#{batch_two.id}", "MILL-LOT-2026-77")

    {:ok, label_view, _html} =
      live(conn, ~p"/manage/production/batches/#{batch_one.batch_code}/label")

    assert has_element?(label_view, "#label-batch-code", batch_one.batch_code)
    assert has_element?(label_view, "#label-ingredients", "Trace Flour")
    assert has_element?(label_view, "#label-batch-barcode")
    assert has_element?(label_view, "#label-size-selector")

    flour
    |> Changeset.for_update(:update, %{name: "Renamed After Production"})
    |> Ash.update!(actor: actor)

    {:ok, frozen_label_view, _html} =
      live(conn, ~p"/manage/production/batches/#{batch_one.batch_code}/label")

    assert has_element?(frozen_label_view, "#label-ingredients", "Trace Flour")
    refute render(frozen_label_view) =~ "Renamed After Production"
  end

  defp completed_batch(product, item, lot, material, quantity, actor) do
    quantity = D.new(quantity)
    {:ok, batch} = Batching.open_batch(product.id, quantity, actor: actor)

    Orders.create_order_item_batch_allocation!(
      %{
        production_batch_id: batch.id,
        order_item_id: item.id,
        planned_qty: quantity
      },
      actor: actor
    )

    {:ok, batch} = Batching.start_batch(batch, actor: actor)

    {:ok, completed} =
      Orders.complete_batch(
        batch,
        %{
          produced_qty: quantity,
          completed_map: %{item.id => quantity},
          lot_plan: %{
            material.id => [%{lot_id: lot.id, quantity: D.mult(quantity, D.new("100"))}]
          }
        },
        actor: actor
      )

    completed
  end
end
