defmodule Craftplan.CSV.Exporters.Traceability do
  @moduledoc false

  alias NimbleCSV.RFC4180, as: CSV

  @headers [
    "direction",
    "ingredient",
    "supplier_lot",
    "internal_lot",
    "lot_status",
    "supplier",
    "purchase_order",
    "finished_product",
    "finished_batch",
    "quantity_used",
    "order",
    "customer",
    "email",
    "phone",
    "delivery_address",
    "consumed_material",
    "via_intermediates",
    "quantity_basis"
  ]

  def export(result) do
    rows =
      Enum.flat_map(result.lots, &forward_rows/1) ++
        Enum.flat_map(result.batches, &backward_rows/1)

    [@headers | rows] |> CSV.dump_to_iodata() |> IO.iodata_to_binary()
  end

  defp forward_rows(report) do
    base = source_columns(report.lot, report.source)

    case report.batches do
      [] -> [base ++ empty_destination() ++ ["", "", ""]]
      batches -> Enum.flat_map(batches, &forward_batch_rows(base, &1))
    end
  end

  defp forward_batch_rows(base, usage) do
    Enum.flat_map(usage.consumptions, fn consumption ->
      batch_columns = [
        usage.batch.product.name,
        usage.batch.batch_code,
        to_string(consumption.quantity_used)
      ]

      context = [
        consumption.consumed_material.name,
        Enum.join(usage.via, " → "),
        "finished_batch_consumption"
      ]

      case usage.orders do
        [] -> [base ++ batch_columns ++ ["", "", "", "", ""] ++ context]
        orders -> Enum.map(orders, &(base ++ batch_columns ++ order_columns(&1) ++ context))
      end
    end)
  end

  defp backward_rows(report) do
    Enum.flat_map(report.lots, fn usage ->
      origins = Map.get(usage, :origins, [])

      direct =
        source_columns(usage.lot, usage.source, "backward") ++
          [
            report.product.name,
            report.batch.batch_code,
            to_string(usage.quantity_used),
            "",
            "",
            "",
            "",
            "",
            usage.lot.material.name,
            Enum.map_join(origins, " → ", & &1.batch.lot_code),
            "finished_batch_consumption"
          ]

      source_rows =
        Enum.flat_map(origins, fn origin ->
          Enum.map(origin.inputs, fn input ->
            source_columns(input.lot, input.source, "intermediate-source") ++
              [
                report.product.name,
                report.batch.batch_code,
                to_string(input.quantity),
                "",
                "",
                "",
                "",
                "",
                input.lot.material.name,
                origin.batch.lot_code,
                "whole_intermediate_batch"
              ]
          end)
        end)

      [direct | source_rows]
    end)
  end

  defp source_columns(lot, source, direction \\ "forward") do
    [
      direction,
      lot.material.name,
      lot.supplier_lot_code || "",
      lot.lot_code,
      to_string(lot.status || :available),
      (source.supplier && source.supplier.name) || "",
      source.purchase_order_reference || ""
    ]
  end

  defp empty_destination, do: ["", "", "", "", "", "", "", ""]

  defp order_columns(order) do
    [
      order.reference || "",
      order.customer_name || "",
      order.customer_email || "",
      order.customer_phone || "",
      address_text(order.shipping_address)
    ]
  end

  defp address_text(nil), do: ""

  defp address_text(address) do
    [:street, :zip, :city, :state, :country]
    |> Enum.map(&Map.get(address, &1))
    |> Enum.reject(&(&1 in [nil, ""]))
    |> Enum.join(", ")
  end
end
