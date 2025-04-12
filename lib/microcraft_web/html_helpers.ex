defmodule MicrocraftWeb.HtmlHelpers do
  @moduledoc """
  Helper functions for formatting and displaying data in HTML templates
  """

  alias Microcraft.Types.Unit

  # Formatting helpers

  @spec format_percentage(Decimal.t() | integer() | nil, Keyword.t()) :: Decimal.t()
  def format_percentage(value, opts \\ [])
  def format_percentage(nil, opts), do: format_percentage(Decimal.new(0), opts)

  def format_percentage(value, opts) when is_integer(value), do: format_percentage(Decimal.new(value), opts)

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

  @doc """
  Format a reference ID for display
  """
  def format_reference(nil), do: "N/A"

  def format_reference(reference) when is_binary(reference) do
    if String.length(reference) > 8 do
      "#{String.slice(reference, 0, 4)}...#{String.slice(reference, -4, 4)}"
    else
      reference
    end
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

  @doc """
  Format short date for compact displays
  """
  def format_short_date(nil, _time_zone), do: "N/A"

  def format_short_date(datetime, time_zone) do
    case datetime do
      %DateTime{} ->
        datetime
        |> DateTime.shift_zone!(time_zone)
        |> Calendar.strftime("%d")

      %Date{} ->
        # Handle Date objects directly without timezone conversion
        Calendar.strftime(datetime, "%d")

      _ ->
        "N/A"
    end
  end

  def is_weekend?(date) do
    day_of_week = Date.day_of_week(date)
    day_of_week == 6 || day_of_week == 7
  end

  def is_today?(date) do
    Date.compare(date, Date.utc_today()) == :eq
  end

  def is_current_week?(day) do
    today = Date.utc_today()
    # Get the beginning of current week (Monday)
    current_monday = Date.add(today, -(Date.day_of_week(today) - 1))
    # Get the beginning of the week for the given day
    day_monday = Date.add(day, -(Date.day_of_week(day) - 1))

    Date.compare(current_monday, day_monday) == :eq
  end

  @doc """
  Safely adds two values that could be either Decimal or integers.
  Returns a Decimal or integer depending on the inputs.
  """
  def safe_add(%Decimal{} = a, %Decimal{} = b), do: Decimal.add(a, b)
  def safe_add(%Decimal{} = a, b) when is_integer(b), do: Decimal.add(a, Decimal.new(b))
  def safe_add(a, %Decimal{} = b) when is_integer(a), do: Decimal.add(Decimal.new(a), b)
  def safe_add(a, b) when is_integer(a) and is_integer(b), do: a + b
  # Fallback, return the first value in case of unexpected input
  def safe_add(a, _), do: a

  @doc """
  Helper to normalize status values
  """
  def normalize_status(status) when is_atom(status), do: Atom.to_string(status)
  def normalize_status(status) when is_binary(status), do: status
  def normalize_status(_), do: "unknown"

  # Status color functions
  @status_colors %{
    order: %{
      unconfirmed: "text-orange-700 border-orange-600",
      confirmed: "text-emerald-700 border-emerald-600",
      in_progress: "text-indigo-700 border-indigo-600",
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
    order_item: %{
      todo: "text-yellow-700 border-yellow-600",
      in_progress: "text-blue-700 border-blue-600",
      done: "text-green-700 border-green-600",
      default: "text-gray-700 border-gray-600"
    }
  }

  @status_backgrounds %{
    order: %{
      unconfirmed: "bg-yellow-50",
      confirmed: "bg-green-50",
      in_progress: "bg-indigo-50",
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
    order_item: %{
      todo: "bg-yellow-100",
      in_progress: "bg-blue-100",
      done: "bg-green-100",
      default: "bg-gray-100"
    }
  }

  @status_dots %{
    active: "bg-green-400",
    archived: "bg-gray-400",
    draft: "bg-yellow-400",
    default: "bg-gray-400"
  }

  @doc """
  Return appropriate CSS classes for status columns in kanban view
  """
  def status_color_class("unconfirmed"), do: "bg-orange-100"
  def status_color_class("confirmed"), do: "bg-blue-100"
  def status_color_class("in_progress"), do: "bg-purple-100"
  def status_color_class("ready"), do: "bg-green-100"
  def status_color_class("delivered"), do: "bg-sky-100"
  def status_color_class("completed"), do: "bg-teal-100"
  def status_color_class("cancelled"), do: "bg-red-100"
  def status_color_class(_), do: "bg-gray-100"

  @doc """
  Status color mapping for calendar events
  """
  # Darker orange
  def get_status_color_hex(:unconfirmed), do: "#f97316"
  # Brighter blue
  def get_status_color_hex(:confirmed), do: "#60a5fa"
  # Brighter purple
  def get_status_color_hex(:in_progress), do: "#a78bfa"
  # Brighter green
  def get_status_color_hex(:ready), do: "#34d399"
  # Brighter sky blue
  def get_status_color_hex(:delivered), do: "#38bdf8"
  # Brighter teal
  def get_status_color_hex(:completed), do: "#2dd4bf"
  # Brighter red
  def get_status_color_hex(:cancelled), do: "#f87171"
  # Darker gray

  # Convert atom status to string for color hex
  def get_status_color_hex(status) when is_binary(status) do
    status
    |> String.to_existing_atom()
    |> get_status_color_hex()
  rescue
    # Default to gray if conversion fails
    _ -> "#6b7280"
  end

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
  def order_item_status_color(status), do: status_color(status, "order_item")

  def product_status_bg(status), do: status_bg(status, "product")
  def order_status_bg(status), do: status_bg(status, "order")
  def payment_status_bg(status), do: status_bg(status, "payment")
  def order_item_status_bg(status), do: status_bg(status, "order_item")

  def product_status_dot(status) do
    @status_dots[status] || @status_dots[:default]
  end

  @doc """
  Get an emoji for a payment status.
  """
  def emoji_for_payment("paid"), do: "✅"
  def emoji_for_payment(:paid), do: "✅"
  def emoji_for_payment("pending"), do: "⏳"
  def emoji_for_payment(:pending), do: "⏳"
  def emoji_for_payment("to_be_refunded"), do: "↩️"
  def emoji_for_payment(:to_be_refunded), do: "↩️"
  def emoji_for_payment("refunded"), do: "🔄"
  def emoji_for_payment(:refunded), do: "🔄"
  def emoji_for_payment(_), do: "❓"
end
