defmodule MicrocraftWeb.HtmlHelpers do
  @moduledoc false

  alias Microcraft.Types.Unit

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
    Money.from_float!(currency, Decimal.to_float(amount), fractional_digits: 4)
  end

  def format_amount(unit, nil), do: format_amount(unit, Decimal.new(0))

  def format_amount(unit, %Decimal{} = amount) do
    format_amount(unit, Decimal.to_float(amount))
  end

  def format_amount(unit, %Money{} = amount) when is_atom(unit) do
    "#{amount}/#{Unit.abbreviation(unit)}"
  end

  def format_amount(unit, amount) when is_number(amount) do
    Unit.abbreviation(unit, amount)
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

  @doc """
  Formats a datetime into a time string in the specified timezone.

  Returns a string in the format "HH:MM AM/PM"
  Returns an empty string if timezone is nil.

  ## Parameters
    - datetime: A DateTime struct to format
    - timezone: The timezone to convert the datetime to (e.g. "America/New_York")
  """
  def format_time(_datetime, nil), do: ""

  def format_time(datetime, timezone) do
    datetime
    |> DateTime.shift_zone!(timezone)
    |> Calendar.strftime("%Y-%m-%d %I:%M %p")
  end

  # Status Color Helpers
  defp status_color(:payment_pending, "order"), do: "text-orange-700 border-orange-600"
  defp status_color(:payment_confirmed, "order"), do: "text-emerald-700 border-emerald-600"
  defp status_color(:refunded, "order"), do: "text-rose-700 border-rose-600"
  defp status_color(:cancelled, "order"), do: "text-rose-700 border-rose-600"
  defp status_color(:processing, "order"), do: "text-indigo-700 border-indigo-600"
  defp status_color(:packed, "order"), do: "text-emerald-700 border-emerald-600"
  defp status_color(:in_transit, "order"), do: "text-sky-700 border-sky-600"
  defp status_color(:delivered, "order"), do: "text-emerald-700 border-emerald-600"
  defp status_color(:completed, "order"), do: "text-emerald-700 border-emerald-600"
  defp status_color(_, "order"), do: "text-slate-700 border-slate-600"

  defp status_color(:draft, "product"), do: "text-gray-700 border-gray-600"
  defp status_color(:testing, "product"), do: "text-purple-700 border-purple-600"
  defp status_color(:active, "product"), do: "text-green-700 border-green-600"
  defp status_color(:paused, "product"), do: "text-orange-700 border-orange-600"
  defp status_color(:discontinued, "product"), do: "text-red-700 border-red-600"
  defp status_color(:archived, "product"), do: "text-red-700 border-red-600"
  defp status_color(_, "product"), do: "text-gray-700 border-gray-600"

  defp status_color(:pending, "task"), do: "text-yellow-700 border-yellow-600"
  defp status_color(:in_progress, "task"), do: "text-blue-700 border-blue-600"
  defp status_color(:done, "task"), do: "text-green-700 border-green-600"
  defp status_color(:cancelled, "task"), do: "text-red-700 border-red-600"
  defp status_color(_, "task"), do: "text-gray-700 border-gray-600"

  def product_status_color(status), do: status_color(status, "product")
  def order_status_color(status), do: status_color(status, "order")
  def task_status_color(status), do: status_color(status, "task")

  # Status Background Helpers
  defp status_bg(:payment_pending, "order"), do: "bg-yellow-50"
  defp status_bg(:payment_confirmed, "order"), do: "bg-green-50"
  defp status_bg(:refunded, "order"), do: "bg-red-50"
  defp status_bg(:cancelled, "order"), do: "bg-red-50"
  defp status_bg(:processing, "order"), do: "bg-indigo-50"
  defp status_bg(:packed, "order"), do: "bg-green-50"
  defp status_bg(:in_transit, "order"), do: "bg-blue-50"
  defp status_bg(:delivered, "order"), do: "bg-green-50"
  defp status_bg(:completed, "order"), do: "bg-green-50"
  defp status_bg(_, "order"), do: "bg-slate-50"

  defp status_bg(:draft, "product"), do: "bg-gray-100"
  defp status_bg(:testing, "product"), do: "bg-purple-100"
  defp status_bg(:active, "product"), do: "bg-green-100"
  defp status_bg(:paused, "product"), do: "bg-orange-100"
  defp status_bg(:discontinued, "product"), do: "bg-red-100"
  defp status_bg(:archived, "product"), do: "bg-red-100"
  defp status_bg(_, "product"), do: "bg-gray-100"

  defp status_bg(:pending, "task"), do: "bg-yellow-100"
  defp status_bg(:in_progress, "task"), do: "bg-blue-100"
  defp status_bg(:done, "task"), do: "bg-green-100"
  defp status_bg(:cancelled, "task"), do: "bg-red-100"
  defp status_bg(_, "task"), do: "bg-gray-100"

  def product_status_bg(status), do: status_bg(status, "product")
  def order_status_bg(status), do: status_bg(status, "order")
  def task_status_bg(status), do: status_bg(status, "task")

  # Product Status Dot Helpers
  def product_status_dot(:active), do: "bg-green-400"
  def product_status_dot(:archived), do: "bg-gray-400"
  def product_status_dot(:draft), do: "bg-yellow-400"
  def product_status_dot(_), do: "bg-gray-400"
end
