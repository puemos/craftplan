defmodule MicrocraftWeb.HtmlHelpers do
  @moduledoc """
  Helper functions for formatting and displaying data in HTML templates
  """

  alias Microcraft.Types.Unit

  # Formatting helpers

  @spec format_percentage(Decimal.t() | nil, Keyword.t()) :: Decimal.t()
  def format_percentage(value, opts \\ [])
  def format_percentage(nil, opts), do: format_percentage(Decimal.new(0), opts)

  def format_percentage(value, opts) do
    places = Keyword.get(opts, :places, 2)
    value |> Decimal.mult(100) |> Decimal.round(places)
  end

  @spec format_money(atom(), Decimal.t() | nil) :: Money.t()
  def format_money(currency, nil), do: format_money(currency, Decimal.new(0))

  def format_money(currency, %Decimal{} = amount) do
    Money.from_float!(currency, Decimal.to_float(amount), fractional_digits: 4)
  end

  @spec format_amount(atom(), Decimal.t() | Money.t() | number() | nil) :: String.t()
  def format_amount(unit, nil), do: format_amount(unit, Decimal.new(0))
  def format_amount(unit, %Decimal{} = amount), do: format_amount(unit, Decimal.to_float(amount))

  def format_amount(unit, %Money{} = amount) when is_atom(unit), do: "#{amount}/#{Unit.abbreviation(unit)}"

  def format_amount(unit, amount) when is_number(amount), do: Unit.abbreviation(unit, amount)

  @spec format_label(atom() | String.t(), String.t()) :: String.t()
  def format_label(term, replace \\ " ") do
    term
    |> to_string()
    |> String.replace("_", replace)
  end

  def format_reference(reference), do: format_label(reference, "-")

  @spec format_time(DateTime.t(), String.t() | nil) :: String.t()
  def format_time(_datetime, nil), do: ""

  def format_time(datetime, timezone) do
    case DateTime.shift_zone(datetime, timezone) do
      {:ok, shifted} -> Calendar.strftime(shifted, "%Y-%m-%d %I:%M %p")
      {:error, _} -> ""
    end
  end

  # Status color functions
  @status_colors %{
    order: %{
      unconfirmed: "text-orange-700 border-orange-600",
      confirmed: "text-emerald-700 border-emerald-600",
      in_process: "text-indigo-700 border-indigo-600",
      ready: "text-emerald-700 border-emerald-600",
      delivered: "text-emerald-700 border-emerald-600",
      completed: "text-emerald-700 border-emerald-600",
      cancelled: "text-rose-700 border-rose-600",
      default: "text-slate-700 border-slate-600"
    },
    payment: %{
      pending: "text-orange-700 border-orange-600",
      paid: "text-emerald-700 border-emerald-600",
      to_be_refunded: "text-rose-700 border-rose-600",
      refunded: "text-rose-700 border-rose-600",
      default: "text-slate-700 border-slate-600"
    },
    product: %{
      draft: "text-gray-700 border-gray-600",
      testing: "text-purple-700 border-purple-600",
      active: "text-green-700 border-green-600",
      paused: "text-orange-700 border-orange-600",
      discontinued: "text-red-700 border-red-600",
      archived: "text-red-700 border-red-600",
      default: "text-gray-700 border-gray-600"
    },
    task: %{
      pending: "text-yellow-700 border-yellow-600",
      in_progress: "text-blue-700 border-blue-600",
      done: "text-green-700 border-green-600",
      cancelled: "text-red-700 border-red-600",
      default: "text-gray-700 border-gray-600"
    }
  }

  @status_backgrounds %{
    order: %{
      unconfirmed: "bg-yellow-50",
      confirmed: "bg-green-50",
      in_process: "bg-indigo-50",
      ready: "bg-green-50",
      delivered: "bg-green-50",
      completed: "bg-green-50",
      cancelled: "bg-red-50",
      default: "bg-slate-50"
    },
    payment: %{
      pending: "bg-yellow-50",
      paid: "bg-green-50",
      to_be_refunded: "bg-red-50",
      refunded: "bg-red-50",
      default: "bg-slate-50"
    },
    product: %{
      draft: "bg-gray-100",
      testing: "bg-purple-100",
      active: "bg-green-100",
      paused: "bg-orange-100",
      discontinued: "bg-red-100",
      archived: "bg-red-100",
      default: "bg-gray-100"
    },
    task: %{
      pending: "bg-yellow-100",
      in_progress: "bg-blue-100",
      done: "bg-green-100",
      cancelled: "bg-red-100",
      default: "bg-gray-100"
    }
  }

  @status_dots %{
    active: "bg-green-400",
    archived: "bg-gray-400",
    draft: "bg-yellow-400",
    default: "bg-gray-400"
  }

  defp status_color(status, type) do
    get_in(@status_colors, [String.to_atom(type), status]) ||
      @status_colors[String.to_atom(type)][:default]
  end

  defp status_bg(status, type) do
    get_in(@status_backgrounds, [String.to_atom(type), status]) ||
      @status_backgrounds[String.to_atom(type)][:default]
  end

  def product_status_color(status), do: status_color(status, "product")
  def order_status_color(status), do: status_color(status, "order")
  def payment_status_color(status), do: status_color(status, "payment")
  def task_status_color(status), do: status_color(status, "task")

  def product_status_bg(status), do: status_bg(status, "product")
  def order_status_bg(status), do: status_bg(status, "order")
  def payment_status_bg(status), do: status_bg(status, "payment")
  def task_status_bg(status), do: status_bg(status, "task")

  def product_status_dot(status) do
    @status_dots[status] || @status_dots[:default]
  end
end
