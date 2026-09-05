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
    "delivery_address"
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
      [] -> [base ++ empty_destination()]
      batches -> Enum.flat_map(batches, &forward_batch_rows(base, &1))
    end
  end

  defp forward_batch_rows(base, usage) do
    batch_columns = [
      usage.batch.product.name,
      usage.batch.batch_code,
      to_string(usage.quantity_used)
    ]

    case usage.orders do
      [] -> [base ++ batch_columns ++ ["", "", "", "", ""]]
      orders -> Enum.map(orders, &(base ++ batch_columns ++ order_columns(&1)))
    end
  end

  defp backward_rows(report) do
    Enum.map(report.lots, fn usage ->
      source_columns(usage.lot, usage.source, "backward") ++
        [
          report.product.name,
          report.batch.batch_code,
          to_string(usage.quantity_used),
          "",
          "",
          "",
          "",
          ""
        ]
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
