defmodule Craftplan.CSV.Exporters.Orders do
  @moduledoc false

  alias NimbleCSV.RFC4180, as: CSV

  @headers [
    "reference",
    "currency",
    "delivery_date",
    "invoice_number",
    "invoice_status",
    "payment_method",
    "payment_status",
    "status",
    "subtotal",
    "tax_total",
    "total",
    "customer_name"
  ]

  def export(actor) do
    orders =
      Craftplan.Orders.list_orders!(%{}, actor: actor, load: [:customer])

    rows =
      Enum.map(orders, fn order ->
        [
          order.reference || "",
          to_string(order.currency || ""),
          format_datetime(order.delivery_date),
          order.invoice_number || "",
          to_string(order.invoice_status || ""),
          to_string(order.payment_method || ""),
          to_string(order.payment_status || ""),
          to_string(order.status || ""),
          Money.to_string(order.subtotal),
          Money.to_string(order.tax_total),
          Money.to_string(order.total),
          customer_name(order)
        ]
      end)

    [@headers | rows] |> CSV.dump_to_iodata() |> IO.iodata_to_binary()
  end

  defp customer_name(%{customer: %{full_name: name}}) when is_binary(name), do: name
  defp customer_name(%{customer: %{first_name: f, last_name: l}}), do: "#{f} #{l}"
  defp customer_name(_), do: ""

  defp format_datetime(nil), do: ""
  defp format_datetime(%DateTime{} = dt), do: DateTime.to_iso8601(dt)
  defp format_datetime(other), do: to_string(other)
end
