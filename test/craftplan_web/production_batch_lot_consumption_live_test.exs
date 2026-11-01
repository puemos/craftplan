defmodule CraftplanWeb.ProductionBatchLotConsumptionLiveTest do
  use CraftplanWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Ash.Changeset
  alias Craftplan.Inventory
  alias Craftplan.Orders
  alias Craftplan.Production.Batching
  alias Craftplan.Test.Factory
  alias Decimal, as: D

  @moduletag role: :staff

  setup %{user: actor} do
    flour = Factory.create_material!(%{name: "Flour", unit: :gram}, actor)
    salt = Factory.create_material!(%{name: "Salt", unit: :gram}, actor)
    product = Factory.create_product!(%{name: "Bread"}, actor)

    product
    |> Factory.create_recipe!(
      [
        %{material_id: flour.id, quantity: D.new("100")},
        %{material_id: salt.id, quantity: D.new("2")}
      ],
      actor
    )
    |> Changeset.for_update(:promote, %{})
    |> Ash.update!(actor: actor)

    early = create_lot!(flour, "FLOUR-EARLY", "150", 10, actor)
    late = create_lot!(flour, "FLOUR-LATE", "1000", 30, actor)
    salt_lot = create_lot!(salt, "SALT-LOT", "100", 30, actor)
    expired = create_lot!(flour, "FLOUR-EXPIRED", "500", -1, actor)

    held = create_lot!(flour, "FLOUR-HELD", "500", 5, actor)
    Ash.update!(held, %{}, action: :place_on_hold, actor: actor)

    order =
      Factory.create_order_with_items!(
        Factory.create_customer!(),
        [%{product_id: product.id, quantity: D.new("4"), unit_price: product.price}],
        actor: actor
      )

    item = hd(order.items)

    batch =
      Orders.ProductionBatch
      |> Changeset.for_create(:open_with_allocations, %{
        product_id: product.id,
        planned_qty: D.new("4"),
        allocations: [%{order_item_id: item.id, planned_qty: D.new("4")}]
      })
      |> Ash.create!(actor: actor)

    batch = Orders.start_batch!(batch, %{}, actor: actor)

    {:ok,
     batch: batch,
     item: item,
     flour: flour,
     salt: salt,
     early: early,
     late: late,
     salt_lot: salt_lot,
     expired: expired,
     held: held}
  end

  test "previews the FIFO split for every material and updates it when quantity changes", ctx do
    {:ok, view, _} = live(ctx.conn, ~p"/manage/production/batches/#{ctx.batch.batch_code}")

    assert has_element?(view, "#lot-allocation-preview", "Enter a produced quantity")
    refute has_element?(view, "#manual-lot-selection")

    change_quantity(view, "3")

    assert has_element?(view, "#suggested-lot-#{ctx.early.id}", "150")
    assert has_element?(view, "#suggested-lot-#{ctx.late.id}", "150")
    assert has_element?(view, "#suggested-lot-#{ctx.salt_lot.id}", "6")
    assert has_element?(view, "#suggested-material-#{ctx.flour.id}", "Flour")
    assert has_element?(view, "#suggested-material-#{ctx.salt.id}", "Salt")
    refute has_element?(view, "#suggested-lot-#{ctx.expired.id}")
    refute has_element?(view, "#suggested-lot-#{ctx.held.id}")

    change_quantity(view, "1.25")
    assert has_element?(view, "#suggested-lot-#{ctx.early.id}", "125")
    assert has_element?(view, "#suggested-lot-#{ctx.salt_lot.id}", "2.5")
    refute has_element?(view, "#suggested-lot-#{ctx.late.id}")

    assert D.equal?(
             Ash.reload!(ctx.early, load: [:current_stock], actor: ctx.user).current_stock,
             "150"
           )

    refute Batching.batch_consumed?(ctx.batch, ctx.user)
  end

  test "use suggested fills manual allocations and preserves edits until explicitly restored",
       ctx do
    {:ok, view, _} = live(ctx.conn, ~p"/manage/production/batches/#{ctx.batch.batch_code}")
    change_quantity(view, "3")
    view |> element("#toggle-manual-lots") |> render_click()
    view |> element("#use-suggested-lots") |> render_click()

    assert has_element?(view, "#lot-quantity-#{ctx.early.id}[value='150']")
    assert has_element?(view, "#lot-quantity-#{ctx.late.id}[value='150']")
    assert has_element?(view, "#lot-quantity-#{ctx.salt_lot.id}[value='6']")
    refute has_element?(view, "#lot-quantity-#{ctx.expired.id}")
    refute has_element?(view, "#lot-quantity-#{ctx.held.id}")

    view
    |> form("#complete-batch-form", %{
      "duration_minutes" => "25",
      "completed_map" => %{ctx.item.id => "3"},
      "lot_plan" => %{ctx.flour.id => %{ctx.early.id => "100", ctx.late.id => "200"}}
    })
    |> render_change()

    change_quantity(view, "2")
    assert has_element?(view, "#lot-quantity-#{ctx.early.id}[value='100']")
    assert has_element?(view, "#lot-quantity-#{ctx.late.id}[value='200']")

    view |> element("#use-suggested-lots") |> render_click()
    assert has_element?(view, "#lot-quantity-#{ctx.early.id}[value='150']")
    assert has_element?(view, "#lot-quantity-#{ctx.late.id}[value='50']")
    assert has_element?(view, "#lot-quantity-#{ctx.salt_lot.id}[value='4']")
    assert has_element?(view, "#batch-duration-minutes[value='25']")
    assert has_element?(view, "#completed-quantity-#{ctx.item.id}[value='3']")

    change_quantity(view, "1")
    view |> element("#use-suggested-lots") |> render_click()
    assert has_element?(view, "#lot-quantity-#{ctx.late.id}[value='']")
    assert has_element?(view, "#lot-quantity-#{ctx.early.id}[value='100']")
  end

  test "clears stale suggestions for invalid quantities and explains insufficient stock", ctx do
    {:ok, view, _} = live(ctx.conn, ~p"/manage/production/batches/#{ctx.batch.batch_code}")
    change_quantity(view, "3")

    for quantity <- ["", "0", "-1"] do
      change_quantity(view, quantity)
      refute has_element?(view, "#suggested-lot-#{ctx.early.id}")
      assert has_element?(view, "#lot-allocation-preview", "Enter a produced quantity")
    end

    change_quantity(view, "12")
    assert has_element?(view, "#lot-allocation-preview-error", "Flour")
    assert has_element?(view, "#lot-allocation-preview-error", "50")
    refute has_element?(view, "#suggested-lot-#{ctx.early.id}")

    view |> element("#toggle-manual-lots") |> render_click()
    assert has_element?(view, "#use-suggested-lots[disabled]")
    change_quantity(view, "3")
    refute has_element?(view, "#lot-allocation-preview-error")
    assert has_element?(view, "#use-suggested-lots:not([disabled])")
  end

  test "completion shows the recorded lot quantities after reload and later stock changes", ctx do
    {:ok, view, _} = live(ctx.conn, ~p"/manage/production/batches/#{ctx.batch.batch_code}")

    view
    |> form("#complete-batch-form", %{
      "produced_qty" => "3",
      "completed_map" => %{ctx.item.id => "3"}
    })
    |> render_submit()

    refute has_element?(view, "#complete-batch-form")
    assert_recorded_lots(view, ctx)

    Inventory.adjust_stock!(
      %{
        material_id: ctx.flour.id,
        lot_id: ctx.early.id,
        quantity: D.new("40"),
        reason: "New stock"
      },
      actor: ctx.user
    )

    {:ok, reloaded, _} = live(ctx.conn, ~p"/manage/production/batches/#{ctx.batch.batch_code}")
    assert_recorded_lots(reloaded, ctx)
  end

  test "completes with edited suggestions and records the chosen lots", ctx do
    {:ok, view, _} = live(ctx.conn, ~p"/manage/production/batches/#{ctx.batch.batch_code}")
    change_quantity(view, "3")
    view |> element("#toggle-manual-lots") |> render_click()
    view |> element("#use-suggested-lots") |> render_click()

    view
    |> form("#complete-batch-form", %{
      "completed_map" => %{ctx.item.id => "3"},
      "lot_plan" => %{ctx.flour.id => %{ctx.early.id => "0", ctx.late.id => "300"}}
    })
    |> render_submit()

    assert has_element?(view, "#batch-summary", "completed")
    refute has_element?(view, "#consumed-lot-#{ctx.early.id}")
    assert has_element?(view, "#consumed-lot-#{ctx.late.id} td:nth-child(4)", "300g")
    assert has_element?(view, "#consumed-lot-#{ctx.salt_lot.id} td:nth-child(4)", "6g")

    assert D.equal?(
             Ash.reload!(ctx.early, load: [:current_stock], actor: ctx.user).current_stock,
             "150"
           )
  end

  test "uses automatic allocation when the manual fields are left empty", ctx do
    {:ok, view, _} = live(ctx.conn, ~p"/manage/production/batches/#{ctx.batch.batch_code}")
    change_quantity(view, "3")
    view |> element("#toggle-manual-lots") |> render_click()

    view
    |> form("#complete-batch-form", %{"completed_map" => %{ctx.item.id => "3"}})
    |> render_submit()

    assert_recorded_lots(view, ctx)
  end

  test "use suggested refreshes the allocation after another stock movement", ctx do
    {:ok, view, _} = live(ctx.conn, ~p"/manage/production/batches/#{ctx.batch.batch_code}")
    change_quantity(view, "3")
    view |> element("#toggle-manual-lots") |> render_click()

    Inventory.adjust_stock!(
      %{
        material_id: ctx.flour.id,
        lot_id: ctx.early.id,
        quantity: D.new("-100"),
        reason: "Another batch"
      },
      actor: ctx.user
    )

    view |> element("#use-suggested-lots") |> render_click()
    assert has_element?(view, "#lot-quantity-#{ctx.early.id}[value='50']")
    assert has_element?(view, "#lot-quantity-#{ctx.late.id}[value='250']")
    assert has_element?(view, "#suggested-lot-#{ctx.early.id}", "50 g")
  end

  test "an incomplete manual allocation explains the mismatch without consuming stock", ctx do
    {:ok, view, _} = live(ctx.conn, ~p"/manage/production/batches/#{ctx.batch.batch_code}")
    change_quantity(view, "3")
    view |> element("#toggle-manual-lots") |> render_click()
    view |> element("#use-suggested-lots") |> render_click()

    view
    |> form("#complete-batch-form", %{
      "completed_map" => %{ctx.item.id => "3"},
      "lot_plan" => %{ctx.flour.id => %{ctx.early.id => "100"}}
    })
    |> render_submit()

    assert has_element?(view, "#flash-error", "Flour must total 300; received 250")
    assert has_element?(view, "#lot-quantity-#{ctx.early.id}[value='100']")
    assert has_element?(view, "#completed-quantity-#{ctx.item.id}[value='3']")
    refute Batching.batch_consumed?(ctx.batch, ctx.user)

    view
    |> form("#complete-batch-form", %{"lot_plan" => %{ctx.flour.id => %{ctx.early.id => "150"}}})
    |> render_submit()

    assert has_element?(view, "#batch-summary", "completed")
    assert has_element?(view, "#flash-info", "Batch completed")
    refute has_element?(view, "#flash-error")
  end

  test "keeps the submitted quantities when completion fails and recovers from invalid input",
       ctx do
    {:ok, view, _} = live(ctx.conn, ~p"/manage/production/batches/#{ctx.batch.batch_code}")
    change_quantity(view, "12")

    view
    |> form("#complete-batch-form", %{"duration_minutes" => "25"})
    |> render_submit()

    assert has_element?(view, "#batch-produced-qty[value='12']")
    assert has_element?(view, "#batch-duration-minutes[value='25']")
    assert has_element?(view, "#lot-allocation-preview-error", "Flour")
    assert has_element?(view, "#manual-lot-selection")

    for quantity <- ["NaN", "Infinity", "invalid"] do
      render_change(view, "validate_completion", %{"produced_qty" => quantity})
      refute has_element?(view, "#suggested-lot-#{ctx.early.id}")
      render_submit(view, "complete_batch", %{"produced_qty" => quantity})
      assert has_element?(view, "#flash-error", "Invalid completion payload")
    end

    change_quantity(view, "3")
    view |> element("#use-suggested-lots") |> render_click()

    render_submit(view, "complete_batch", %{
      "produced_qty" => "3",
      "lot_plan" => %{ctx.flour.id => %{ctx.early.id => "NaN"}}
    })

    assert has_element?(view, "#flash-error", "Invalid completion payload")
    refute Batching.batch_consumed?(ctx.batch, ctx.user)
  end

  test "shows recorded consumption rather than a new suggestion if materials were already consumed",
       ctx do
    {:ok, plan} = Batching.auto_select_lots(ctx.batch, "4")
    {:ok, _} = Batching.consume_batch(ctx.batch, plan, actor: ctx.user)
    {:ok, view, _} = live(ctx.conn, ~p"/manage/production/batches/#{ctx.batch.batch_code}")
    change_quantity(view, "4")

    assert has_element?(view, "#lot-allocation-preview", "Materials have already been consumed")
    refute has_element?(view, "#toggle-manual-lots")
    refute has_element?(view, "#suggested-lot-#{ctx.early.id}")
    assert has_element?(view, "#consumed-lot-#{ctx.early.id} td:nth-child(4)", "150g")
    assert has_element?(view, "#consumed-lot-#{ctx.late.id} td:nth-child(4)", "250g")
  end

  test "explains that a batch without a recipe has no material lots to pick", ctx do
    product = Factory.create_product!(%{name: "No recipe"}, ctx.user)
    {:ok, batch} = Batching.open_batch(product.id, "1", actor: ctx.user)
    batch = Orders.start_batch!(batch, %{}, actor: ctx.user)
    {:ok, view, _} = live(ctx.conn, ~p"/manage/production/batches/#{batch.batch_code}")

    change_quantity(view, "1")
    assert has_element?(view, "#lot-allocation-preview", "This batch requires no material lots")
    view |> element("#toggle-manual-lots") |> render_click()
    assert has_element?(view, "#use-suggested-lots[disabled]")
  end

  defp assert_recorded_lots(view, ctx) do
    for {lot, quantity} <- [{ctx.early, "150g"}, {ctx.late, "150g"}, {ctx.salt_lot, "6g"}] do
      assert has_element?(view, "#consumed-lot-#{lot.id}", lot.lot_code)
      assert has_element?(view, "#consumed-lot-#{lot.id} td:nth-child(4)", quantity)
    end
  end

  defp change_quantity(view, quantity) do
    view |> form("#complete-batch-form", %{"produced_qty" => quantity}) |> render_change()
  end

  defp create_lot!(material, code, quantity, expiry_offset, actor) do
    lot =
      Inventory.Lot
      |> Changeset.for_create(:create, %{
        lot_code: code,
        material_id: material.id,
        expiry_date: Date.add(Date.utc_today(), expiry_offset),
        received_at: DateTime.utc_now()
      })
      |> Ash.create!(actor: actor)

    Inventory.adjust_stock!(
      %{
        material_id: material.id,
        lot_id: lot.id,
        quantity: D.new(quantity),
        reason: "Initial stock"
      },
      actor: actor
    )

    lot
  end
end
