defmodule Craftplan.IntermediateProductionTest do
  use Craftplan.DataCase, async: true

  alias Ash.Changeset
  alias Craftplan.CSV.Exporters.Traceability
  alias Craftplan.Inventory.Intermediates
  alias Craftplan.Inventory.Lot
  alias Craftplan.Inventory.MaterialBatch
  alias Craftplan.Inventory.MaterialRecipe
  alias Craftplan.Inventory.Movement
  alias Craftplan.Test.Factory
  alias Decimal, as: D

  setup do
    actor = staff_actor()
    oil = Factory.create_material!(%{name: "Raw oil", price: D.new("0.01")}, actor)
    blend = Factory.create_material!(%{name: "Stocked blend", price: D.new("0.02")}, actor)

    lot =
      Lot
      |> Changeset.for_create(:create, %{
        material_id: oil.id,
        lot_code: "RAW-01",
        received_quantity: 1000,
        unit_cost: "0.015",
        expiry_date: Date.add(Date.utc_today(), 30)
      })
      |> Ash.create!(actor: actor)

    Movement
    |> Changeset.for_create(:adjust_stock, %{material_id: oil.id, lot_id: lot.id, quantity: 1000})
    |> Ash.create!(actor: actor)

    recipe =
      MaterialRecipe
      |> Changeset.for_create(:create, %{
        material_id: blend.id,
        yield_quantity: 250,
        components: [%{material_id: oil.id, quantity: 300}]
      })
      |> Ash.create!(actor: actor)

    %{actor: actor, oil: oil, blend: blend, lot: lot, recipe: recipe}
  end

  defp produce(ctx, attrs \\ %{}) do
    params =
      Map.merge(
        %{
          material_id: ctx.blend.id,
          recipe_id: ctx.recipe.id,
          planned_quantity: 250,
          actual_quantity: 240,
          lot_code: "BLEND-01",
          inputs: [%{lot_id: ctx.lot.id, quantity: 300}]
        },
        attrs
      )

    MaterialBatch |> Changeset.for_create(:produce, params) |> Ash.create(actor: ctx.actor)
  end

  test "production consumes actual inputs once and stocks actual yield with frozen cost and genealogy",
       ctx do
    assert {:ok, batch} = produce(ctx)
    batch = Ash.load!(batch, [:output_lot, inputs: [:lot]], actor: ctx.actor)
    assert D.equal?(Ash.load!(ctx.lot, :current_stock, actor: ctx.actor).current_stock, 700)

    assert D.equal?(
             Ash.load!(batch.output_lot, :current_stock, actor: ctx.actor).current_stock,
             240
           )

    assert D.equal?(batch.total_cost, "4.5")
    assert D.equal?(batch.output_lot.unit_cost, "0.01875")
    assert hd(batch.inputs).lot.id == ctx.lot.id
    assert batch.recipe_snapshot["version"] == 1
    assert {:error, _} = produce(ctx)

    assert D.equal?(
             Ash.reload!(ctx.lot, load: :current_stock, actor: ctx.actor).current_stock,
             700
           )
  end

  test "insufficient stock rolls back output, genealogy and movements", ctx do
    assert {:error, _} = produce(ctx, %{inputs: [%{lot_id: ctx.lot.id, quantity: 1001}]})
    assert Ash.count!(MaterialBatch, actor: ctx.actor) == 0
    assert Ash.count!(Lot, actor: ctx.actor) == 1
    assert Ash.count!(Movement, actor: ctx.actor) == 1
  end

  test "held lots are excluded and completion rejects them even if the form is stale", ctx do
    ctx.lot |> Changeset.for_update(:place_on_hold, %{}) |> Ash.update!(actor: ctx.actor)
    assert {:error, error} = produce(ctx)
    assert Exception.message(error) =~ "not available"
    assert Ash.count!(MaterialBatch, actor: ctx.actor) == 0
  end

  test "actual inputs can differ from standard recipe and split across lots", ctx do
    second =
      Lot
      |> Changeset.for_create(:create, %{
        material_id: ctx.oil.id,
        lot_code: "RAW-02",
        unit_cost: "0.02"
      })
      |> Ash.create!(actor: ctx.actor)

    Movement
    |> Changeset.for_create(:adjust_stock, %{
      material_id: ctx.oil.id,
      lot_id: second.id,
      quantity: 100
    })
    |> Ash.create!(actor: ctx.actor)

    assert {:ok, batch} =
             produce(ctx, %{
               inputs: [%{lot_id: ctx.lot.id, quantity: 280}, %{lot_id: second.id, quantity: 20}]
             })

    assert D.equal?(batch.total_cost, "4.6")
    assert length(Ash.load!(batch, :inputs, actor: ctx.actor).inputs) == 2
  end

  test "foreign recipe, repeated lot, and missing or additional materials are rejected", ctx do
    other = Factory.create_material!(%{name: "Different input"}, ctx.actor)

    foreign =
      MaterialRecipe
      |> Changeset.for_create(:create, %{
        material_id: other.id,
        yield_quantity: 100,
        components: [%{material_id: ctx.oil.id, quantity: 100}]
      })
      |> Ash.create!(actor: ctx.actor)

    assert {:error, _} = produce(ctx, %{recipe_id: foreign.id})
    assert {:error, _} = produce(ctx, %{inputs: []})

    assert {:error, _} =
             produce(ctx, %{
               inputs: [
                 %{lot_id: ctx.lot.id, quantity: 150},
                 %{lot_id: ctx.lot.id, quantity: 150}
               ]
             })

    assert {:error, _} = produce(ctx, %{actual_quantity: 0})
    assert Ash.count!(MaterialBatch, actor: ctx.actor) == 0
  end

  test "recipe revisions leave completed batch snapshots intact", ctx do
    assert {:ok, batch} = produce(ctx)

    new_recipe =
      MaterialRecipe
      |> Changeset.for_create(:create, %{
        material_id: ctx.blend.id,
        yield_quantity: 300,
        components: [%{material_id: ctx.oil.id, quantity: 320}]
      })
      |> Ash.create!(actor: ctx.actor)

    assert new_recipe.version == 2
    assert Intermediates.latest_recipe(ctx.blend.id, ctx.actor).id == new_recipe.id

    assert Ash.reload!(batch, actor: ctx.actor).recipe_snapshot["components"] ==
             ctx.recipe.components
  end

  test "self-consuming and repeated-input recipes are rejected", ctx do
    for components <- [
          [%{material_id: ctx.blend.id, quantity: 1}],
          [%{material_id: ctx.oil.id, quantity: 1}, %{material_id: ctx.oil.id, quantity: 1}]
        ] do
      assert {:error, _} =
               MaterialRecipe
               |> Changeset.for_create(:create, %{
                 material_id: ctx.blend.id,
                 yield_quantity: 250,
                 components: components
               })
               |> Ash.create(actor: ctx.actor)
    end
  end

  test "finished products consume intermediate stock only and inherit actual lot costs", ctx do
    assert {:ok, intermediate} = produce(ctx)
    product = Factory.create_product!(%{name: "Blend product"}, ctx.actor)
    bom = Factory.create_recipe!(product, [%{material_id: ctx.blend.id, quantity: 50}], ctx.actor)
    bom |> Changeset.for_update(:promote, %{}) |> Ash.update!(actor: ctx.actor)
    customer = Factory.create_customer!()

    order =
      Factory.create_order_with_items!(
        customer,
        [%{product_id: product.id, quantity: 2, unit_price: 10}],
        actor: ctx.actor
      )

    batch =
      Craftplan.Orders.open_batch_with_allocations!(
        %{
          product_id: product.id,
          planned_qty: 2,
          allocations: [%{order_item_id: hd(order.items).id, planned_qty: 2}]
        },
        actor: ctx.actor
      )

    batch = Craftplan.Orders.start_batch!(batch, %{}, actor: ctx.actor)
    finished = Craftplan.Orders.complete_batch!(batch, %{produced_qty: 2}, actor: ctx.actor)

    assert D.equal?(
             Ash.reload!(ctx.lot, load: :current_stock, actor: ctx.actor).current_stock,
             700
           )

    assert D.equal?(
             Craftplan.Inventory.get_lot_by_id!(intermediate.output_lot_id,
               load: :current_stock,
               actor: ctx.actor
             ).current_stock,
             140
           )

    item = Craftplan.Orders.get_order_item_by_id!(hd(order.items).id, actor: ctx.actor)
    assert D.equal?(item.material_cost, "1.875")
    forward = Craftplan.Traceability.lookup(ctx.lot.lot_code, actor: ctx.actor)
    assert [report] = forward.lots
    assert [node] = report.intermediates
    assert node.batch.id == intermediate.id
    assert [usage] = report.batches
    assert usage.batch.id == finished.id
    assert usage.via == [intermediate.lot_code]
    assert usage.consumed_material.id == ctx.blend.id
    assert hd(usage.orders).reference == order.reference
    backward = Craftplan.Traceability.lookup(finished.batch_code, actor: ctx.actor)
    assert [finished_report] = backward.batches
    assert [consumption] = finished_report.lots
    assert hd(hd(consumption.origins).inputs).lot.id == ctx.lot.id
    csv = Traceability.export(backward)
    assert csv =~ "intermediate-source"
    assert csv =~ ctx.lot.lot_code
    assert csv =~ "whole_intermediate_batch"
    forward_csv = Traceability.export(forward)
    assert forward_csv =~ intermediate.lot_code
    assert forward_csv =~ "Stocked blend"
    assert forward_csv =~ "finished_batch_consumption"
  end

  test "genealogy crosses multiple stocked intermediate generations", ctx do
    assert {:ok, intermediate} = produce(ctx)
    second = Factory.create_material!(%{name: "Second-stage blend"}, ctx.actor)

    second_recipe =
      MaterialRecipe
      |> Changeset.for_create(:create, %{
        material_id: second.id,
        yield_quantity: 90,
        components: [%{material_id: ctx.blend.id, quantity: 100}]
      })
      |> Ash.create!(actor: ctx.actor)

    second_batch =
      MaterialBatch
      |> Changeset.for_create(:produce, %{
        material_id: second.id,
        recipe_id: second_recipe.id,
        planned_quantity: 90,
        actual_quantity: 90,
        lot_code: "SECOND-STAGE-01",
        inputs: [%{lot_id: intermediate.output_lot_id, quantity: 100}]
      })
      |> Ash.create!(actor: ctx.actor)

    assert D.equal?(second_batch.total_cost, "1.875")
    report = hd(Craftplan.Traceability.lookup(ctx.lot.lot_code, actor: ctx.actor).lots)
    assert Enum.map(report.intermediates, & &1.batch.id) == [intermediate.id, second_batch.id]
    output = hd(Craftplan.Traceability.lookup(second_batch.lot_code, actor: ctx.actor).lots)
    assert Enum.map(output.origins, & &1.batch.id) == [second_batch.id, intermediate.id]
  end

  test "blank and malformed component quantities produce validation errors", ctx do
    for components <- [
          [%{material_id: "", quantity: ""}],
          [%{material_id: ctx.oil.id, quantity: nil}],
          [%{material_id: ctx.oil.id, quantity: "bad"}]
        ] do
      assert {:error, _} =
               MaterialRecipe
               |> Changeset.for_create(:create, %{
                 material_id: ctx.blend.id,
                 yield_quantity: 100,
                 components: components
               })
               |> Ash.create(actor: ctx.actor)
    end
  end

  test "customer actors cannot produce stock", ctx do
    customer = Craftplan.Test.AuthHelpers.register_user!(role: :customer)
    assert {:error, _} = produce(%{ctx | actor: customer})
    assert Ash.count!(Lot, actor: ctx.actor) == 1
  end
end
