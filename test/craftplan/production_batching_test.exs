defmodule Craftplan.ProductionBatchingTest do
  use Craftplan.DataCase, async: true

  alias Ash.Changeset
  alias Craftplan.Inventory
  alias Craftplan.Orders
  alias Craftplan.Production.Batching
  alias Craftplan.Test.Factory
  alias Decimal, as: D

  defp setup_product_with_material(actor) do
    product =
      Factory.create_product!(
        %{name: "Sourdough", sku: "sourdough", price: D.new("12.00")},
        actor
      )

    flour = Factory.create_material!(%{name: "Flour", unit: :gram, price: D.new("0.01")}, actor)

    bom =
      Factory.create_recipe!(product, [%{material_id: flour.id, quantity: D.new("500")}], actor)

    # Promote BOM to active so batch open can snapshot components_map
    bom
    |> Changeset.for_update(:promote, %{})
    |> Ash.update!(actor: actor)

    {product, flour}
  end

  defp create_lot_with_stock(material_id, lot_code, stock_qty, actor, opts \\ []) do
    expiry_offset = Keyword.get(opts, :expiry_offset, 60)

    {:ok, lot} =
      Inventory.Lot
      |> Changeset.for_create(:create, %{
        lot_code: lot_code,
        material_id: material_id,
        expiry_date: Date.add(Date.utc_today(), expiry_offset),
        received_at: DateTime.utc_now()
      })
      |> Ash.create(actor: actor)

    _ =
      Inventory.Movement
      |> Changeset.for_create(:adjust_stock, %{
        material_id: material_id,
        lot_id: lot.id,
        quantity: D.new(stock_qty),
        reason: "Seed stock"
      })
      |> Ash.create!(actor: actor)

    lot
  end

  defp setup_orders_and_allocations(product, batch, actor) do
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

    {item1, item2}
  end

  test "open, auto-consume, and complete batch allocates costs and updates items" do
    actor = Craftplan.DataCase.staff_actor()

    {product, flour} = setup_product_with_material(actor)

    _lot = create_lot_with_stock(flour.id, "FLOT-1", "50000", actor)

    {:ok, batch} = Batching.open_batch(product.id, D.new("15"), actor: actor)

    {item1, item2} = setup_orders_and_allocations(product, batch, actor)

    # Start the batch
    {:ok, batch} = Batching.start_batch(batch, actor: actor)

    # Complete (auto-consumes via FIFO — no separate consume step)
    batch
    |> Changeset.for_update(:complete, %{produced_qty: D.new("15")}, actor: actor)
    |> Ash.update!(actor: actor)

    # Verify items progressed
    item1 = Orders.get_order_item_by_id!(item1.id, actor: actor, load: [:status])
    item2 = Orders.get_order_item_by_id!(item2.id, actor: actor, load: [:status])

    assert item1.status in [:in_progress, :done]
    assert item2.status in [:in_progress, :done]
  end

  test "open, consume manually, and complete batch allocates costs and updates items" do
    actor = Craftplan.DataCase.staff_actor()

    {product, flour} = setup_product_with_material(actor)

    lot = create_lot_with_stock(flour.id, "FLOT-1", "50000", actor)

    {:ok, batch} = Batching.open_batch(product.id, D.new("15"), actor: actor)

    {item1, item2} = setup_orders_and_allocations(product, batch, actor)

    # Start the batch
    {:ok, batch} = Batching.start_batch(batch, actor: actor)

    # Complete with explicit lot_plan (manual selection)
    lot_plan = %{
      flour.id => [%{lot_id: lot.id, quantity: D.new("7500")}]
    }

    batch
    |> Changeset.new()
    |> Changeset.set_argument(:lot_plan, lot_plan)
    |> Changeset.for_update(:complete, %{produced_qty: D.new("15")}, actor: actor)
    |> Ash.update!(actor: actor)

    item1 = Orders.get_order_item_by_id!(item1.id, actor: actor, load: [:status])
    item2 = Orders.get_order_item_by_id!(item2.id, actor: actor, load: [:status])

    assert item1.status in [:in_progress, :done]
    assert item2.status in [:in_progress, :done]
  end

  describe "auto_select_lots/2" do
    test "selects lots in FIFO order (earliest expiry first)" do
      actor = Craftplan.DataCase.staff_actor()

      {product, flour} = setup_product_with_material(actor)

      # Create two lots with different expiry dates
      lot_early = create_lot_with_stock(flour.id, "FLOT-EARLY", "5000", actor, expiry_offset: 10)
      lot_late = create_lot_with_stock(flour.id, "FLOT-LATE", "10000", actor, expiry_offset: 60)

      {:ok, batch} = Batching.open_batch(product.id, D.new("15"), actor: actor)

      # 500g/unit * 15 = 7500g needed
      {:ok, plan} = Batching.auto_select_lots(batch, D.new("15"))

      assert map_size(plan) == 1
      entries = plan |> Map.values() |> hd()

      # Should take from early lot first (5000g), then late lot (2500g)
      assert length(entries) == 2
      [first, second] = entries
      assert first.lot_id == lot_early.id
      assert D.equal?(first.quantity, D.new("5000"))
      assert second.lot_id == lot_late.id
      assert D.equal?(second.quantity, D.new("2500"))
    end

    test "returns error when insufficient stock" do
      actor = Craftplan.DataCase.staff_actor()

      {product, flour} = setup_product_with_material(actor)

      # Only 100g available, but need 7500g for 15 units
      _lot = create_lot_with_stock(flour.id, "FLOT-SMALL", "100", actor)

      {:ok, batch} = Batching.open_batch(product.id, D.new("15"), actor: actor)

      assert {:error, {:insufficient_stock, _material_id, required, short}} =
               Batching.auto_select_lots(batch, D.new("15"))

      assert D.equal?(required, D.new("7500"))
      assert D.gt?(short, D.new(0))
    end

    test "returns ok with empty plan when no components" do
      actor = Craftplan.DataCase.staff_actor()

      product =
        Factory.create_product!(
          %{name: "NoComp", sku: "nocomp", price: D.new("5.00")},
          actor
        )

      {:ok, batch} = Batching.open_batch(product.id, D.new("10"), actor: actor)

      assert {:ok, plan} = Batching.auto_select_lots(batch, D.new("10"))
      assert plan == %{}
    end
  end
end
