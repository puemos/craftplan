defmodule Craftplan.Production.BatchSheet do
  @moduledoc """
  Generates a printable PDF batch sheet using Imprintor (Typst).
  """

  alias Craftplan.Production
  alias Decimal, as: D

  @template_path "priv/typst/batch_sheet.typ"

  @doc """
  Generates a PDF binary for the given batch code.

  Returns `{:ok, pdf_binary}` or `{:error, reason}`.
  """
  def generate_pdf(batch_code, opts \\ []) do
    actor = Keyword.get(opts, :actor)
    currency = Keyword.get(opts, :currency, :USD)

    report = Production.batch_report!(batch_code, actor: actor)
    bom = load_bom_details(report.bom, actor)

    data = build_data(report, bom, currency)
    template = File.read!(Application.app_dir(:craftplan, @template_path))

    config = Imprintor.Config.new(template, data)
    Imprintor.compile_to_pdf(config)
  end

  defp load_bom_details(nil, _actor), do: nil

  defp load_bom_details(bom, actor) do
    Ash.load!(bom, [:labor_steps, components: [:material]], actor: actor)
  end

  defp build_data(report, bom, currency) do
    batch = report.production_batch
    product = report.product
    completed? = batch && batch.status == :completed

    %{
      "batch_code" => report.batch_code,
      "product_name" => (product && product.name) || "Unknown",
      "product_sku" => (product && product.sku) || "",
      "status" => format_status(batch),
      "planned_qty" => format_decimal((batch && batch.planned_qty) || D.new(0)),
      "produced_at" => format_datetime(report.produced_at),
      "observations" => (bom && bom.notes) || "",
      "orders" => build_orders(report.orders),
      "bom_components" => build_bom_components(bom, report.totals),
      "labor_steps" => build_labor_steps(bom),
      "lots" => build_lots(report.lots),
      "show_costs" => if(completed?, do: "yes", else: "no"),
      "costs" => build_costs(report.totals, currency)
    }
  end

  defp build_orders(orders) do
    Enum.map(orders, fn order ->
      %{
        "reference" => order.order.reference || "",
        "customer_name" => order.customer_name || "—",
        "quantity" => format_decimal(order.quantity),
        "delivery_date" => format_date(order.order.delivery_date)
      }
    end)
  end

  defp build_bom_components(nil, _totals), do: []

  defp build_bom_components(bom, totals) do
    planned_qty = (totals && totals.quantity) || D.new(0)

    bom.components
    |> Enum.filter(&(&1.component_type == :material))
    |> Enum.sort_by(& &1.position)
    |> Enum.map(fn comp ->
      material = comp.material
      qty_per = comp.quantity || D.new(0)
      total_req = D.mult(qty_per, planned_qty)

      %{
        "name" => (material && material.name) || "Unknown",
        "qty_per_unit" => format_decimal(qty_per),
        "total_required" => format_decimal(total_req),
        "unit" => (material && to_string(material.unit)) || "",
        "waste_percent" => format_decimal(comp.waste_percent || D.new(0))
      }
    end)
  end

  defp build_labor_steps(nil), do: []

  defp build_labor_steps(bom) do
    bom.labor_steps
    |> Enum.sort_by(& &1.sequence)
    |> Enum.map(fn step ->
      %{
        "sequence" => to_string(step.sequence),
        "name" => step.name,
        "duration_minutes" => format_decimal(step.duration_minutes),
        "units_per_run" => format_decimal(step.units_per_run)
      }
    end)
  end

  defp build_lots(lots) do
    Enum.map(lots, fn lot ->
      %{
        "lot_code" => lot.lot_code || "—",
        "material_name" => (lot.material && lot.material.name) || "Unknown",
        "quantity_used" => format_decimal(lot.quantity_used),
        "expiry_date" => format_date(lot.expiry_date),
        "supplier" => (lot.supplier && lot.supplier.name) || "—"
      }
    end)
  end

  defp build_costs(nil, _currency) do
    blank = "—"

    %{
      "material_cost" => blank,
      "labor_cost" => blank,
      "overhead_cost" => blank,
      "total_cost" => blank,
      "unit_cost" => blank
    }
  end

  defp build_costs(totals, currency) do
    %{
      "material_cost" => format_money(currency, totals.material_cost),
      "labor_cost" => format_money(currency, totals.labor_cost),
      "overhead_cost" => format_money(currency, totals.overhead_cost),
      "total_cost" => format_money(currency, totals.total_cost),
      "unit_cost" => format_money(currency, totals.unit_cost)
    }
  end

  defp format_status(nil), do: "Unknown"

  defp format_status(batch), do: batch.status |> to_string() |> String.replace("_", " ") |> String.capitalize()

  defp format_decimal(%D{} = d), do: D.to_string(D.normalize(d))
  defp format_decimal(_), do: "0"

  defp format_date(nil), do: "—"
  defp format_date(%Date{} = d), do: Calendar.strftime(d, "%b %d, %Y")

  defp format_date(%DateTime{} = dt), do: dt |> DateTime.to_date() |> format_date()

  defp format_date(%NaiveDateTime{} = ndt), do: ndt |> NaiveDateTime.to_date() |> format_date()

  defp format_date(_), do: "—"

  defp format_datetime(nil), do: ""
  defp format_datetime(%DateTime{} = dt), do: Calendar.strftime(dt, "%b %d, %Y %H:%M")
  defp format_datetime(%NaiveDateTime{} = ndt), do: Calendar.strftime(ndt, "%b %d, %Y %H:%M")
  defp format_datetime(_), do: ""

  defp format_money(currency, %D{} = amount) do
    currency |> Money.new(amount) |> Money.to_string!()
  end

  defp format_money(currency, _), do: format_money(currency, D.new(0))
end
