defmodule MicrocraftWeb.HtmlHelpers do
  @moduledoc false

  def format_percentage(value) do
    format_percentage(value, [])
  end

  def format_percentage(nil, opts) do
    format_percentage(Decimal.new(0), opts)
  end

  def format_percentage(value, opts) do
    places = Keyword.get(opts, :places, 2)

    value
    |> Decimal.mult(100)
    |> Decimal.round(places)
  end

  def format_money(currency, nil), do: format_money(currency, Decimal.new(0))

  def format_money(currency, %Decimal{} = amount) do
    Money.from_float!(currency, Decimal.to_float(amount))
  end

  def format_label(term) when is_atom(term) do
    term
    |> Atom.to_string()
    |> String.replace("_", " ")
  end

  def format_label(term) when is_binary(term) do
    String.replace(term, "_", " ")
  end

  def format_label(term) when is_number(term) do
    term
    |> Integer.to_string()
    |> String.replace("_", " ")
  end

  def format_score(score) when is_float(score) do
    "#{:erlang.float_to_binary(score, decimals: 1)} / 5.0"
  end

  def format_score(score) when is_integer(score) do
    "#{score}.0 / 5.0"
  end

  # Status Color Helpers
  defp status_color(:pending, "payment"), do: "text-yellow-700"
  defp status_color(:paid, "payment"), do: "text-green-700"
  defp status_color(:refunded, "payment"), do: "text-red-700"
  defp status_color(_, "payment"), do: "text-gray-700"

  defp status_color(:draft, "product"), do: "text-gray-700"
  defp status_color(:experiment, "product"), do: "text-purple-700"
  defp status_color(:active, "product"), do: "text-green-700"
  defp status_color(:inactive, "product"), do: "text-red-700"
  defp status_color(_, "product"), do: "text-gray-700"

  defp status_color(:pending, "order"), do: "text-yellow-700"
  defp status_color(:confirmed, "order"), do: "text-blue-700"
  defp status_color(:in_production, "order"), do: "text-purple-700"
  defp status_color(:ready, "order"), do: "text-green-700"
  defp status_color(:completed, "order"), do: "text-gray-700"
  defp status_color(:cancelled, "order"), do: "text-red-700"
  defp status_color(_, "order"), do: "text-gray-700"

  def payment_status_color(status), do: status_color(status, "payment")
  def product_status_color(status), do: status_color(status, "product")
  def order_status_color(status), do: status_color(status, "order")

  # Status Background Helpers
  defp status_bg(:pending, "payment"), do: "bg-yellow-100"
  defp status_bg(:paid, "payment"), do: "bg-green-100"
  defp status_bg(:refunded, "payment"), do: "bg-red-100"
  defp status_bg(_, "payment"), do: "bg-gray-100"

  defp status_bg(:draft, "product"), do: "bg-gray-100"
  defp status_bg(:experiment, "product"), do: "bg-purple-100"
  defp status_bg(:active, "product"), do: "bg-green-100"
  defp status_bg(:inactive, "product"), do: "bg-red-100"
  defp status_bg(_, "product"), do: "bg-gray-100"

  defp status_bg(:pending, "order"), do: "bg-yellow-100"
  defp status_bg(:confirmed, "order"), do: "bg-blue-100"
  defp status_bg(:in_production, "order"), do: "bg-purple-100"
  defp status_bg(:ready, "order"), do: "bg-green-100"
  defp status_bg(:completed, "order"), do: "bg-gray-100"
  defp status_bg(:cancelled, "order"), do: "bg-red-100"
  defp status_bg(_, "order"), do: "bg-gray-100"

  def payment_status_bg(status), do: status_bg(status, "payment")
  def product_status_bg(status), do: status_bg(status, "product")
  def order_status_bg(status), do: status_bg(status, "order")

  # Product Status Dot Helpers
  def product_status_dot(:active), do: "bg-green-400"
  def product_status_dot(:inactive), do: "bg-gray-400"
  def product_status_dot(:pending), do: "bg-yellow-400"
  def product_status_dot(_), do: "bg-gray-400"
end
