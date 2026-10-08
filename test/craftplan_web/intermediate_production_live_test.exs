defmodule CraftplanWeb.IntermediateProductionLiveTest do
  use CraftplanWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Ash.Changeset
  alias Craftplan.Inventory.Lot
  alias Craftplan.Inventory.MaterialBatch
  alias Craftplan.Inventory.MaterialRecipe
  alias Craftplan.Inventory.Movement
  alias Craftplan.Test.Factory
  alias Decimal, as: D

  @tag role: :staff
  test "change and split lots without losing result details between steps", %{
    conn: conn,
    user: actor
  } do
    input = Factory.create_material!(%{name: "Split ingredient"}, actor)
    output = Factory.create_material!(%{name: "Split blend"}, actor)

    lots =
      for code <- ["SPLIT-FIRST", "SPLIT-SECOND"] do
        lot =
          Lot
          |> Changeset.for_create(:create, %{material_id: input.id, lot_code: code})
          |> Ash.create!(actor: actor)

        Movement
        |> Changeset.for_create(:adjust_stock, %{
          material_id: input.id,
          lot_id: lot.id,
          quantity: 500
        })
        |> Ash.create!(actor: actor)

        lot
      end

    MaterialRecipe
    |> Changeset.for_create(:create, %{
      material_id: output.id,
      yield_quantity: 500,
      components: [%{material_id: input.id, quantity: 600}]
    })
    |> Ash.create!(actor: actor)

    {:ok, view, _} = live(conn, ~p"/manage/inventory/#{output.sku}/production")
    view |> element("#make-material-batch") |> render_click()
    assert has_element?(view, "#batch-input-quantity-1[value='100']")
    view |> element("button[phx-click='remove_lot'][phx-value-index='1']") |> render_click()
    view |> element("#change-input-lot-0") |> render_click()
    refute has_element?(view, "#batch-lot-options-0.hidden")
    view |> element("#split-input-lot-0") |> render_click()
    assert has_element?(view, "#batch-lot-options-1:not(.hidden)")

    view
    |> element("#material-batch-form")
    |> render_change(%{
      "batch" => %{
        "inputs" => %{
          "0" => %{"material_id" => input.id, "lot_id" => hd(lots).id, "quantity" => "500"},
          "1" => %{"material_id" => input.id, "lot_id" => List.last(lots).id, "quantity" => "100"}
        }
      }
    })

    view |> element("#material-batch-form") |> render_submit()

    view
    |> element("#material-batch-form")
    |> render_change(%{
      "batch" => %{
        "lot_code" => "SPLIT-OUTPUT",
        "actual_quantity" => "480",
        "notes" => "Measured loss",
        "expiry_date" => "2027-01-01"
      }
    })

    view |> element("button[phx-click='back_to_plan']") |> render_click()
    view |> element("#material-batch-form") |> render_submit()
    assert has_element?(view, "#batch_lot_code[value='SPLIT-OUTPUT']")
    assert has_element?(view, "#batch_actual_quantity[value='480']")
    assert Ash.count!(MaterialBatch, actor: actor) == 0
    view |> element("#material-batch-form") |> render_submit()
    assert [batch] = Ash.read!(MaterialBatch, load: [:inputs], actor: actor)
    assert length(batch.inputs) == 2
    assert batch.notes == "Measured loss"
    assert batch.expiry_date == ~D[2027-01-01]
    assert D.equal?(batch.actual_quantity, 480)
  end

  @tag role: :staff
  test "create a recipe, scale a batch, record lower actual yield, and see its input lots", %{
    conn: conn,
    user: actor
  } do
    input = Factory.create_material!(%{name: "Raw ingredient"}, actor)
    output = Factory.create_material!(%{name: "House blend"}, actor)

    lot =
      Lot
      |> Changeset.for_create(:create, %{
        material_id: input.id,
        lot_code: "LIVE-RAW-01",
        unit_cost: "0.01"
      })
      |> Ash.create!(actor: actor)

    Movement
    |> Changeset.for_create(:adjust_stock, %{
      material_id: input.id,
      lot_id: lot.id,
      quantity: 1000
    })
    |> Ash.create!(actor: actor)

    {:ok, view, _} = live(conn, ~p"/manage/inventory/#{output.sku}/production")
    assert has_element?(view, "#make-material-batch[disabled]")
    view |> element("#edit-material-recipe") |> render_click()
    view |> element("button[phx-click='remove_component'][phx-value-index='1']") |> render_click()

    view
    |> element("#material-recipe-form")
    |> render_submit(%{
      "recipe" => %{
        "yield_quantity" => "250",
        "notes" => "Blend well",
        "components" => %{"0" => %{"material_id" => input.id, "quantity" => "300"}}
      }
    })

    refute has_element?(view, "#make-material-batch[disabled]")
    view |> element("#make-material-batch") |> render_click()
    assert has_element?(view, "#batch-input-quantity-0[value='300']")

    view
    |> element("#material-batch-form")
    |> render_change(%{"batch" => %{"planned_quantity" => "500"}})

    assert has_element?(view, "#batch-input-quantity-0[value='600']")
    refute has_element?(view, "#complete-material-batch")
    view |> element("#material-batch-form") |> render_submit()
    assert has_element?(view, "#complete-material-batch")
    assert Ash.count!(MaterialBatch, actor: actor) == 0

    view
    |> element("#material-batch-form")
    |> render_change(%{"batch" => %{"actual_quantity" => "480"}})

    view |> element("button[phx-click='back_to_plan']") |> render_click()

    view
    |> element("#material-batch-form")
    |> render_change(%{"batch" => %{"planned_quantity" => "600"}})

    assert has_element?(view, "#batch_actual_quantity[value='480']")

    view
    |> element("#material-batch-form")
    |> render_change(%{"batch" => %{"planned_quantity" => "500"}})

    view |> element("#material-batch-form") |> render_submit()

    view
    |> element("#material-batch-form")
    |> render_submit(%{
      "batch" => %{
        "planned_quantity" => "500",
        "actual_quantity" => "480",
        "lot_code" => "LIVE-BLEND-01",
        "expiry_date" => "",
        "notes" => "Small process loss",
        "inputs" => %{
          "0" => %{"material_id" => input.id, "lot_id" => lot.id, "quantity" => "600"}
        }
      }
    })

    refute has_element?(view, "#material-batch-modal")
    assert [batch] = Ash.read!(MaterialBatch, actor: actor)
    assert has_element?(view, "#material-batches-#{batch.id}")
    refute has_element?(view, "#material-batches-#{batch.id}[open]")
    assert has_element?(view, "#produced-material-stock", "480g")
    assert D.equal?(Ash.reload!(input, load: :current_stock, actor: actor).current_stock, 400)
    assert has_element?(view, "#material-batches-#{batch.id} a[href*='traceability']")
  end

  @tag role: :staff
  test "stock failure keeps the form open with an actionable message and no output", %{
    conn: conn,
    user: actor
  } do
    input = Factory.create_material!(%{name: "Limited raw input"}, actor)
    output = Factory.create_material!(%{name: "Stocked output"}, actor)

    lot =
      Lot
      |> Changeset.for_create(:create, %{material_id: input.id, lot_code: "LIMITED-RAW"})
      |> Ash.create!(actor: actor)

    Movement
    |> Changeset.for_create(:adjust_stock, %{material_id: input.id, lot_id: lot.id, quantity: 10})
    |> Ash.create!(actor: actor)

    MaterialRecipe
    |> Changeset.for_create(:create, %{
      material_id: output.id,
      yield_quantity: 100,
      components: [%{material_id: input.id, quantity: 100}]
    })
    |> Ash.create!(actor: actor)

    {:ok, view, _} = live(conn, ~p"/manage/inventory/#{output.sku}/production")
    view |> element("#make-material-batch") |> render_click()
    view |> element("button[phx-click='remove_lot'][phx-value-index='1']") |> render_click()
    view |> element("#material-batch-form") |> render_submit()

    view
    |> element("#material-batch-form")
    |> render_submit(%{
      "batch" => %{
        "planned_quantity" => "100",
        "actual_quantity" => "100",
        "lot_code" => "TOO-LARGE",
        "expiry_date" => "",
        "notes" => "",
        "inputs" => %{
          "0" => %{"material_id" => input.id, "lot_id" => lot.id, "quantity" => "100"}
        }
      }
    })

    assert has_element?(view, "#batch-error", "Insufficient stock")
    assert has_element?(view, "#material-batch-form")
    assert Ash.count!(MaterialBatch, actor: actor) == 0

    assert D.equal?(
             Ash.reload!(output, load: :current_stock, actor: actor).current_stock || D.new(0),
             0
           )
  end
end
