defmodule CraftplanWeb.ProductionBatchLiveActionsTest do
  use CraftplanWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Craftplan.Catalog.Product
  alias Craftplan.Orders

  # ── Helpers ──────────────────────────────────────────────────────

  defp staff, do: Craftplan.DataCase.staff_actor()

  defp product_with_bom! do
    Product
    |> Ash.Changeset.for_create(:create, %{
      name: "P-#{System.unique_integer()}",
      sku: "SKU-#{System.unique_integer()}",
      price: Money.new("5.00", :USD),
      status: :active
    })
    |> Ash.create!(actor: staff())
  end

  defp open_batch(product) do
    {:ok, batch} =
      Orders.ProductionBatch
      |> Ash.Changeset.for_create(:open, %{
        product_id: product.id,
        planned_qty: Decimal.new("1")
      })
      |> Ash.create(actor: staff())

    customer =
      Craftplan.CRM.Customer
      |> Ash.Changeset.for_create(:create, %{
        type: :individual,
        first_name: "T",
        last_name: "U"
      })
      |> Ash.create!()

    order =
      Orders.Order
      |> Ash.Changeset.for_create(:create, %{
        customer_id: customer.id,
        delivery_date: DateTime.utc_now()
      })
      |> Ash.create!(actor: staff())

    order_item =
      Orders.OrderItem
      |> Ash.Changeset.for_create(:create, %{
        product_id: product.id,
        quantity: Decimal.new("1"),
        unit_price: product.price,
        status: :todo
      })
      |> Ash.Changeset.force_change_attribute(:order_id, order.id)
      |> Ash.Changeset.force_change_attribute(:batch_code, batch.batch_code)
      |> Ash.Changeset.force_change_attribute(:production_batch_id, batch.id)
      |> Ash.create!(actor: staff())

    {batch, order, order_item}
  end

  defp create_allocation!(batch, order_item, planned \\ "1") do
    Orders.OrderItemBatchAllocation
    |> Ash.Changeset.for_create(:create, %{
      production_batch_id: batch.id,
      order_item_id: order_item.id,
      planned_qty: Decimal.new(planned),
      completed_qty: Decimal.new("0")
    })
    |> Ash.create!(actor: staff())
  end

  defp create_material_with_lot!(name, stock_qty) do
    actor = staff()

    material =
      Craftplan.Inventory.Material
      |> Ash.Changeset.for_create(:create, %{
        name: name,
        sku: "MAT-#{System.unique_integer([:positive])}",
        unit: :gram,
        price: Money.new("1.00", :USD),
        minimum_stock: Decimal.new(0),
        maximum_stock: Decimal.new(0)
      })
      |> Ash.create!(actor: actor)

    lot =
      Craftplan.Inventory.Lot
      |> Ash.Changeset.for_create(:create, %{
        lot_code: "LOT-#{System.unique_integer([:positive])}",
        material_id: material.id,
        expiry_date: Date.add(Date.utc_today(), 30)
      })
      |> Ash.create!(actor: actor)

    # Create positive stock via movement
    Craftplan.Inventory.adjust_stock!(
      %{
        quantity: Decimal.new(stock_qty),
        reason: "Initial stock",
        material_id: material.id,
        lot_id: lot.id
      },
      actor: actor
    )

    {material, lot}
  end

  defp open_batch_with_components(product, components_map) do
    import Ecto.Query

    {batch, order, order_item} = open_batch(product)

    # Directly update via Ecto to bypass Ash action restrictions
    Craftplan.Repo.update_all(
      from(b in "orders_production_batches",
        where: b.id == type(^batch.id, :binary_id),
        update: [set: [components_map: ^components_map]]
      ),
      []
    )

    {Ash.reload!(batch), order, order_item}
  end

  # ── Batch lifecycle ─────────────────────────────────────────────

  describe "batch lifecycle" do
    @tag role: :staff
    test "start action transitions batch to in_progress", %{conn: conn} do
      prod = product_with_bom!()
      {batch, _order, _item} = open_batch(prod)

      {:ok, view, html} = live(conn, ~p"/manage/production/batches/#{batch.batch_code}")

      assert html =~ "open"
      assert has_element?(view, "button[phx-click=start_batch]")

      view |> element("button[phx-click=start_batch]") |> render_click()

      html = render(view)
      assert html =~ "in_progress"
      assert html =~ "Batch started"
    end

    @tag role: :staff
    test "batch show page displays summary cards with correct data", %{conn: conn} do
      prod = product_with_bom!()
      {batch, _order, _item} = open_batch(prod)

      {:ok, view, html} = live(conn, ~p"/manage/production/batches/#{batch.batch_code}")

      assert html =~ "Batch #{batch.batch_code}"
      assert has_element?(view, "#batch-summary")
      assert html =~ "Product"
      assert html =~ "Status"
      assert html =~ "Produced"
      assert html =~ "Average Unit Cost"
    end

    @tag role: :staff
    test "action buttons only appear for correct batch status", %{conn: conn} do
      prod = product_with_bom!()
      {batch, _order, _item} = open_batch(prod)

      {:ok, view, _html} = live(conn, ~p"/manage/production/batches/#{batch.batch_code}")

      # Open batch: start button visible, inline form hidden
      assert has_element?(view, "button[phx-click=start_batch]")
      refute has_element?(view, "#complete-batch-section")

      # Start the batch
      view |> element("button[phx-click=start_batch]") |> render_click()

      # In-progress: start hidden, inline complete form visible
      refute has_element?(view, "button[phx-click=start_batch]")
      assert has_element?(view, "#complete-batch-section")
      assert has_element?(view, "#complete-batch-form")
    end
  end

  # ── Inline complete form ───────────────────────────────────────

  describe "inline complete form" do
    @tag role: :staff
    test "displays produced_qty and duration inputs when in_progress", %{conn: conn} do
      prod = product_with_bom!()
      {batch, _order, _item} = open_batch(prod)

      {:ok, view, _} = live(conn, ~p"/manage/production/batches/#{batch.batch_code}")
      view |> element("button[phx-click=start_batch]") |> render_click()

      assert has_element?(view, "#complete-batch-section")
      assert has_element?(view, ~s(input[name="produced_qty"]))
      assert has_element?(view, ~s(input[name="duration_minutes"]))
    end

    @tag role: :staff
    test "shows allocation details when allocations exist", %{conn: conn} do
      prod = product_with_bom!()
      {batch, order, order_item} = open_batch(prod)
      create_allocation!(batch, order_item, "3")

      {:ok, view, _} = live(conn, ~p"/manage/production/batches/#{batch.batch_code}")
      view |> element("button[phx-click=start_batch]") |> render_click()

      html = render(view)
      assert html =~ "Completed quantities per order item"
      assert html =~ "planned:"
      assert html =~ "3"
      assert html =~ order.reference
      assert html =~ prod.name
    end

    @tag role: :staff
    test "does not show allocation section when no allocations", %{conn: conn} do
      prod = product_with_bom!()
      {batch, _order, _item} = open_batch(prod)

      {:ok, view, _} = live(conn, ~p"/manage/production/batches/#{batch.batch_code}")
      view |> element("button[phx-click=start_batch]") |> render_click()

      html = render(view)
      refute html =~ "Completed quantities per order item"
    end

    @tag role: :staff
    test "advanced toggle shows lot selection", %{conn: conn} do
      prod = product_with_bom!()
      {material, _lot} = create_material_with_lot!("Sugar", "500")

      components_map = %{material.id => "10"}
      {batch, _order, _item} = open_batch_with_components(prod, components_map)

      {:ok, view, _} = live(conn, ~p"/manage/production/batches/#{batch.batch_code}")
      view |> element("button[phx-click=start_batch]") |> render_click()

      # Lot selection not visible by default
      html = render(view)
      refute html =~ "Sugar"

      # Toggle advanced lots
      view |> element("input[phx-click=toggle_advanced_lots]") |> render_click()

      html = render(view)
      assert html =~ "Sugar"
      assert html =~ "Required:"
      assert html =~ "stock:"
    end

    @tag role: :staff
    test "successfully completes batch with auto-FIFO (no advanced toggle)", %{conn: conn} do
      prod = product_with_bom!()
      {batch, _order, order_item} = open_batch(prod)
      create_allocation!(batch, order_item)

      {:ok, view, _} = live(conn, ~p"/manage/production/batches/#{batch.batch_code}")
      view |> element("button[phx-click=start_batch]") |> render_click()

      view
      |> form("#complete-batch-form", %{
        "produced_qty" => "1",
        "duration_minutes" => "10",
        "completed_map" => %{order_item.id => "1"}
      })
      |> render_submit()

      html = render(view)
      assert html =~ "completed"
    end

    @tag role: :staff
    test "successfully completes batch with manual lot selection", %{conn: conn} do
      prod = product_with_bom!()
      {material, lot} = create_material_with_lot!("Butter", "200")

      components_map = %{material.id => "5"}
      {batch, _order, order_item} = open_batch_with_components(prod, components_map)
      create_allocation!(batch, order_item)

      {:ok, view, _} = live(conn, ~p"/manage/production/batches/#{batch.batch_code}")
      view |> element("button[phx-click=start_batch]") |> render_click()

      # Enable advanced toggle
      view |> element("input[phx-click=toggle_advanced_lots]") |> render_click()

      view
      |> form("#complete-batch-form", %{
        "produced_qty" => "1",
        "duration_minutes" => "10",
        "completed_map" => %{order_item.id => "1"},
        "lot_plan" => %{material.id => %{lot.id => "5"}}
      })
      |> render_submit()

      html = render(view)
      assert html =~ "completed"
    end

    @tag role: :staff
    test "completes batch without duration (optional)", %{conn: conn} do
      prod = product_with_bom!()
      {batch, _order, order_item} = open_batch(prod)
      create_allocation!(batch, order_item)

      {:ok, view, _} = live(conn, ~p"/manage/production/batches/#{batch.batch_code}")
      view |> element("button[phx-click=start_batch]") |> render_click()

      view
      |> form("#complete-batch-form", %{
        "produced_qty" => "1",
        "completed_map" => %{order_item.id => "1"}
      })
      |> render_submit()

      assert render(view) =~ "completed"
    end

    @tag role: :staff
    test "shows error flash when produced_qty is missing", %{conn: conn} do
      prod = product_with_bom!()
      {batch, _order, _item} = open_batch(prod)

      {:ok, view, _} = live(conn, ~p"/manage/production/batches/#{batch.batch_code}")
      view |> element("button[phx-click=start_batch]") |> render_click()

      view
      |> form("#complete-batch-form", %{"produced_qty" => ""})
      |> render_submit()

      html = render(view)
      assert html =~ "Invalid completion payload"
    end

    @tag role: :staff
    test "shows error flash when no allocations exist for complete", %{conn: conn} do
      prod = product_with_bom!()
      {batch, _order, _item} = open_batch(prod)

      {:ok, view, _} = live(conn, ~p"/manage/production/batches/#{batch.batch_code}")
      view |> element("button[phx-click=start_batch]") |> render_click()

      view
      |> form("#complete-batch-form", %{
        "produced_qty" => "1",
        "duration_minutes" => "5"
      })
      |> render_submit()

      html = render(view)
      assert html =~ "Complete failed"
    end
  end

  # ── Full workflow ───────────────────────────────────────────────

  describe "full batch workflow" do
    @tag role: :staff
    test "open → start → complete lifecycle (auto-FIFO)", %{conn: conn} do
      prod = product_with_bom!()
      {batch, _order, order_item} = open_batch(prod)
      create_allocation!(batch, order_item)

      {:ok, view, html} = live(conn, ~p"/manage/production/batches/#{batch.batch_code}")
      assert html =~ "open"

      # Step 1: Start
      view |> element("button[phx-click=start_batch]") |> render_click()
      assert render(view) =~ "in_progress"

      # Step 2: Complete (auto-consumes via FIFO)
      view
      |> form("#complete-batch-form", %{
        "produced_qty" => "1",
        "duration_minutes" => "20",
        "completed_map" => %{order_item.id => "1"}
      })
      |> render_submit()

      html = render(view)
      assert html =~ "completed"

      # After completion, no action buttons or forms should appear
      refute has_element?(view, "button[phx-click=start_batch]")
      refute has_element?(view, "#complete-batch-section")
    end
  end
end
