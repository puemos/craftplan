defmodule Craftplan.Orders.InvoicePdf do
  @moduledoc """
  Generates a printable invoice PDF using Imprintor (Typst).
  """

  alias Craftplan.Orders
  alias Decimal, as: D

  @template_path "priv/typst/invoice.typ"

  @doc """
  Generates a PDF binary for the given order reference.

  Returns `{:ok, pdf_binary}` or `{:error, reason}`.
  """
  def generate_pdf(reference, opts \\ []) do
    actor = Keyword.get(opts, :actor)
    currency = Keyword.get(opts, :currency, :USD)

    order =
      Orders.get_order_by_reference!(reference,
        load: [
          :subtotal,
          :shipping_total,
          :tax_total,
          :discount_total,
          :total,
          :delivery_date,
          customer: [:full_name, shipping_address: [:full_address]],
          items: [:cost, :unit_price, product: [:name]]
        ],
        actor: actor
      )

    data = build_data(order, currency)
    template = File.read!(Application.app_dir(:craftplan, @template_path))

    config = Imprintor.Config.new(template, data)
    Imprintor.compile_to_pdf(config)
  end

  defp build_data(order, currency) do
    customer = order.customer

    %{
      "reference" => order.reference || "",
      "issued_date" => format_date(Date.utc_today()),
      "delivery_date" => format_datetime(order.delivery_date),
      "customer_name" => (customer && customer.full_name) || "",
      "customer_address" => (customer && customer.shipping_address && customer.shipping_address.full_address) || "",
      "items" => build_items(order.items, currency),
      "subtotal" => format_money(currency, order.subtotal),
      "shipping_total" => format_money(currency, order.shipping_total),
      "tax_total" => format_money(currency, order.tax_total),
      "discount_total" => format_money(currency, order.discount_total),
      "total" => format_money(currency, order.total),
      "notes" => ""
    }
  end

  defp build_items(items, currency) do
    Enum.map(items || [], fn item ->
      %{
        "product_name" => (item.product && item.product.name) || "Unknown",
        "quantity" => format_decimal(item.quantity),
        "unit_price" => format_money(currency, item.unit_price),
        "line_total" => format_money(currency, item.cost)
      }
    end)
  end

  defp format_decimal(%D{} = d), do: D.to_string(D.normalize(d))
  defp format_decimal(_), do: "0"

  defp format_date(%Date{} = d), do: Calendar.strftime(d, "%b %d, %Y")
  defp format_date(_), do: ""

  defp format_datetime(nil), do: ""
  defp format_datetime(%DateTime{} = dt), do: dt |> DateTime.to_date() |> format_date()

  defp format_datetime(%NaiveDateTime{} = ndt), do: ndt |> NaiveDateTime.to_date() |> format_date()

  defp format_datetime(%Date{} = d), do: format_date(d)
  defp format_datetime(_), do: ""

  defp format_money(currency, %D{} = amount) do
    currency |> Money.new(amount) |> Money.to_string!()
  end

  defp format_money(_currency, %Money{} = money), do: Money.to_string!(money)
  defp format_money(currency, _), do: format_money(currency, D.new(0))
end
