defmodule Craftplan.Production.BatchSheetTest do
  use ExUnit.Case, async: true

  alias Craftplan.Production.BatchSheet
  alias Decimal, as: D

  defp sheet(scientific_notation?) do
    report = %{
      batch_code: "B-TEST",
      production_batch: %{planned_qty: D.new("1000"), status: :open},
      product: %{name: "Blend", sku: "BLEND"},
      produced_at: nil,
      orders: [
        %{
          order: %{reference: "OR-TEST", delivery_date: nil},
          customer_name: "Test",
          quantity: D.new("1000")
        }
      ],
      lots: [
        %{
          lot_code: "L-TEST",
          material: %{name: "Oil"},
          quantity_used: D.new("0.000001"),
          expiry_date: nil,
          supplier: nil
        }
      ],
      totals: %{
        quantity: D.new("1000"),
        material_cost: D.new(0),
        labor_cost: D.new(0),
        overhead_cost: D.new(0),
        total_cost: D.new(0),
        unit_cost: D.new(0)
      }
    }

    bom = %{
      notes: nil,
      components: [
        %{
          component_type: :material,
          position: 1,
          material: %{name: "Oil", unit: :gram},
          quantity: D.new("1000"),
          waste_percent: D.new("0.001")
        }
      ],
      labor_steps: [
        %{sequence: 1, name: "Mix", duration_minutes: D.new("1000"), units_per_run: D.new("1000")}
      ]
    }

    BatchSheet.build_data(report, bom, :USD, scientific_notation?)
  end

  test "ordinary decimal mode preserves exact large and small quantities throughout the sheet" do
    data = sheet(false)
    assert data["planned_qty"] == "1000"
    assert hd(data["orders"])["quantity"] == "1000"
    assert hd(data["bom_components"])["qty_per_unit"] == "1000"
    assert hd(data["bom_components"])["total_required"] == "1000000"
    assert hd(data["bom_components"])["waste_percent"] == "0.001"
    assert hd(data["bom_components"])["unit"] == "gram"
    assert hd(data["lots"])["quantity_used"] == "0.000001"
    assert hd(data["labor_steps"])["duration_minutes"] == "1000"
    assert hd(data["labor_steps"])["units_per_run"] == "1000"
  end

  test "scientific notation can be enabled" do
    data = sheet(true)
    assert data["planned_qty"] == "1E+3"
    assert hd(data["bom_components"])["total_required"] == "1E+6"
    assert hd(data["lots"])["quantity_used"] == "0.000001"
  end
end
