defmodule CraftplanWeb.HtmlHelpers do
  @moduledoc """
  Helper functions for formatting and displaying data in HTML templates.

  Centralizes UI-facing formatting so LiveViews and components stay consistent.
  """

  alias Craftplan.Types.Unit

  @type datetime_input :: Date.t() | NaiveDateTime.t() | DateTime.t()
  @type format_option ::
          {:format, atom() | String.t()} | {:timezone, String.t()} | {:locale, String.t()}

  # Date & time formatting helpers

  @doc """
  Formats a date-like value using named presets or a custom `Calendar.strftime/2` pattern.

  ## Options
    * `:format` - Atom preset (`:short`, `:medium`, `:long`, `:iso`) or strftime string.
    * `:timezone` - Timezone shift applied to `DateTime`/`NaiveDateTime` inputs.

  Returns `""` when the input is nil.
  """
  @spec format_date(datetime_input | nil, [format_option] | String.t()) :: String.t()
  def format_date(value, opts \\ [])

  def format_date(value, timezone) when is_binary(timezone), do: format_date(value, timezone: timezone)

  def format_date(nil, _opts), do: ""

  def format_date(value, opts) when is_list(opts) do
    format = Keyword.get(opts, :format, :medium)
    timezone = Keyword.get(opts, :timezone)

    value
    |> normalize_datetime(timezone)
    |> do_format_date(format)
  end

  def format_date(_value, _opts), do: ""

  defp do_format_date(nil, _format), do: ""

  defp do_format_date(%Date{} = date, format), do: Calendar.strftime(date, format_pattern(format, :date))

  defp do_format_date(%NaiveDateTime{} = naive, format), do: Calendar.strftime(naive, format_pattern(format, :datetime))

  defp do_format_date(%DateTime{} = datetime, format), do: Calendar.strftime(datetime, format_pattern(format, :datetime))

  @doc """
  Formats a value as a localized day name.

  ## Options
    * `:style` - `:short` (default) or `:long` for full weekday name.
    * `:timezone` - Shift applied before formatting `DateTime`/`NaiveDateTime` inputs.
  """
  @spec format_day_name(datetime_input | nil, Keyword.t()) :: String.t()
  def format_day_name(value, opts \\ [])

  def format_day_name(nil, _opts), do: ""

  def format_day_name(value, opts) do
    style = Keyword.get(opts, :style, :short)
    timezone = Keyword.get(opts, :timezone)

    case normalize_datetime(value, timezone) do
      %Date{} = date -> Calendar.strftime(date, weekday_pattern(style))
      %NaiveDateTime{} = naive -> Calendar.strftime(naive, weekday_pattern(style))
      %DateTime{} = datetime -> Calendar.strftime(datetime, weekday_pattern(style))
      _ -> ""
    end
  end

  defp weekday_pattern(:short), do: "%a"
  defp weekday_pattern(:long), do: "%A"
  defp weekday_pattern(pattern) when is_binary(pattern), do: pattern

  @doc """
  Convenience wrapper returning a short date representation or `"N/A"` when missing.
  Accepts an optional timezone argument for backwards compatibility.
  """
  @spec format_short_date(datetime_input | nil, Keyword.t() | String.t() | nil) :: String.t()
  def format_short_date(value, opts \\ [])

  def format_short_date(value, timezone) when is_binary(timezone), do: format_short_date(value, timezone: timezone)

  def format_short_date(_value, opts) when not is_list(opts), do: "N/A"

  def format_short_date(value, opts) do
    missing = Keyword.get(opts, :missing, "N/A")
    format = Keyword.get(opts, :format, "%d")

    format_opts =
      opts
      |> Keyword.delete(:format)
      |> Keyword.put(:format, format)
      |> Keyword.delete(:missing)

    case format_date(value, format_opts) do
      "" -> missing
      formatted -> formatted
    end
  end

  @doc """
  Generates a range of dates starting from `start`.

  Provide either `:days` (count) or `:until` (`Date.t()`). Defaults to 7 days.
  Optional `:step` controls the increment, defaulting to 1.
  """
  @spec date_range(Date.t(), Keyword.t()) :: [Date.t()]
  def date_range(%Date{} = start, opts \\ []) do
    days = Keyword.get(opts, :days)
    until = Keyword.get(opts, :until)
    step = Keyword.get(opts, :step, 1)

    cond do
      match?(%Date{}, until) ->
        build_range_until(start, until, step)

      is_integer(days) and days > 0 ->
        Enum.map(0..(days - 1), fn offset -> Date.add(start, offset * step) end)

      true ->
        Enum.map(0..6, fn offset -> Date.add(start, offset * step) end)
    end
  end

  defp build_range_until(start, until, step) do
    start
    |> Stream.iterate(&Date.add(&1, step))
    |> Enum.take_while(fn date -> Date.compare(date, until) != :gt end)
  end

  @doc """
  Formats a date/time value as time-of-day.

  ## Options
    * `:format` - `:time12` (default), `:time24`, `:time_short`, or custom pattern.
    * `:timezone` - target timezone for `DateTime` inputs.
  """
  @spec format_time(datetime_input | nil, Keyword.t() | String.t()) :: String.t()
  def format_time(value, opts \\ [])

  def format_time(value, timezone) when is_binary(timezone), do: format_time(value, timezone: timezone)

  def format_time(nil, _opts), do: ""

  def format_time(value, opts) when is_list(opts) do
    format = Keyword.get(opts, :format, :time12)
    timezone = Keyword.get(opts, :timezone)

    value
    |> normalize_datetime(timezone)
    |> do_format_time(format)
  end

  def format_time(_value, _opts), do: ""

  defp do_format_time(nil, _format), do: ""
  defp do_format_time(%Date{} = date, format), do: Calendar.strftime(date, time_pattern(format))

  defp do_format_time(%NaiveDateTime{} = naive, format), do: Calendar.strftime(naive, time_pattern(format))

  defp do_format_time(%DateTime{} = datetime, format), do: Calendar.strftime(datetime, time_pattern(format))

  defp time_pattern(:time12), do: "%I:%M %p"
  defp time_pattern(:time24), do: "%H:%M"
  defp time_pattern(:time_short), do: "%H:%M"
  defp time_pattern(pattern) when is_binary(pattern), do: pattern

  @doc """
  Formats a duration (seconds by default) into a readable string.

  Styles:
    * `:compact` (default) → `"1h 30m"`
    * `:long` → `"1 hour 30 minutes"`
    * `:clock` → `"01:30:00"`
  """
  @spec format_duration(non_neg_integer() | Time.t(), Keyword.t()) :: String.t()
  def format_duration(value, opts \\ [])

  def format_duration(%Time{} = time, opts) do
    time
    |> Time.diff(~T[00:00:00], :second)
    |> format_duration(opts)
  end

  def format_duration(value, opts) when is_integer(value) and value >= 0 do
    style = Keyword.get(opts, :style, :compact)

    hours = div(value, 3600)
    minutes = div(rem(value, 3600), 60)
    seconds = rem(value, 60)

    case style do
      :clock ->
        Enum.map_join(
          [hours, minutes, seconds],
          ":",
          &String.pad_leading(Integer.to_string(&1), 2, "0")
        )

      :long ->
        build_duration_long(hours, minutes, seconds)

      _ ->
        build_duration_compact(hours, minutes, seconds)
    end
  end

  def format_duration(_, _opts), do: ""

  defp build_duration_compact(hours, minutes, seconds) do
    []
    |> maybe_append(hours, fn h -> "#{h}h" end)
    |> maybe_append(minutes, fn m -> "#{m}m" end)
    |> maybe_append(seconds, fn s -> "#{s}s" end)
    |> case do
      [] -> "0s"
      parts -> Enum.join(parts, " ")
    end
  end

  defp build_duration_long(hours, minutes, seconds) do
    []
    |> maybe_append(hours, fn h -> pluralize(h, "hour") end)
    |> maybe_append(minutes, fn m -> pluralize(m, "minute") end)
    |> maybe_append(seconds, fn s -> pluralize(s, "second") end)
    |> case do
      [] -> "0 seconds"
      parts -> Enum.join(parts, " ")
    end
  end

  defp maybe_append(list, 0, _fun), do: list
  defp maybe_append(list, value, fun), do: list ++ [fun.(value)]

  defp pluralize(1, word), do: "1 #{word}"
  defp pluralize(n, word), do: "#{n} #{word}s"

  @doc """
  Formats numeric or decimal values as currency.

  Accepts existing `Money` structs, `Decimal`, integers, floats, or numeric strings.
  Pass `format: :string` to return a rendered string.
  """
  @spec format_currency(atom(), Decimal.t() | Money.t() | number() | nil, Keyword.t()) ::
          Money.t() | String.t()
  def format_currency(currency, amount, opts \\ [])

  def format_currency(currency, nil, opts), do: format_currency(currency, Decimal.new(0), opts)

  def format_currency(_currency, %Money{} = money, opts) do
    if Keyword.get(opts, :format) == :string do
      Money.to_string!(money, opts)
    else
      money
    end
  end

  def format_currency(_currency, {:ok, data} = money, opts) do
    if Keyword.get(opts, :format) == :string do
      Money.to_string!(data, opts)
    else
      data
    end
  end

  def format_currency(currency, %Decimal{} = amount, opts) do
    money = Money.new(currency, amount)
    format_currency(currency, money, opts)
  end

  def format_currency(currency, amount, opts) when is_integer(amount) do
    decimal = Decimal.new(amount)
    format_currency(currency, decimal, opts)
  end

  def format_currency(currency, amount, opts) when is_float(amount) do
    decimal = Decimal.from_float(amount)
    format_currency(currency, decimal, opts)
  end

  def format_currency(currency, amount, opts) when is_binary(amount) do
    case Decimal.new(amount) do
      %Decimal{} = decimal -> format_currency(currency, decimal, opts)
      _ -> format_currency(currency, Decimal.new(0), opts)
    end
  rescue
    _ -> format_currency(currency, Decimal.new(0), opts)
  end

  # Formatting helpers

  @spec format_percentage(Decimal.t() | integer() | nil, Keyword.t()) :: Decimal.t()
  def format_percentage(value, opts \\ [])
  def format_percentage(nil, opts), do: format_percentage(Decimal.new(0), opts)

  def format_percentage(value, opts) when is_integer(value), do: format_percentage(Decimal.new(value), opts)

  def format_percentage(value, opts) do
    places = Keyword.get(opts, :places, 0)
    value |> Decimal.mult(100) |> Decimal.round(places)
  end

  @spec format_money(atom(), Decimal.t() | Money.t() | number() | nil, Keyword.t()) ::
          Money.t() | String.t()
  def format_money(currency, amount, opts \\ []) do
    format_currency(currency, amount, opts)
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

  @doc """
  Format hour for displaying time in 12-hour format with AM/PM
  """
  @spec format_hour(datetime_input | nil, String.t() | nil) :: String.t()
  def format_hour(nil, _timezone), do: ""
  def format_hour(_value, nil), do: ""
  def format_hour(value, timezone), do: format_time(value, format: :time12, timezone: timezone)

  def is_weekend?(date) do
    day_of_week = Date.day_of_week(date)
    day_of_week == 6 || day_of_week == 7
  end

  def is_today?(value, timezone \\ nil) do
    case normalize_datetime(value, timezone) do
      %Date{} = date -> Date.compare(date, Date.utc_today()) == :eq
      %NaiveDateTime{} = naive -> naive |> NaiveDateTime.to_date() |> is_today?()
      %DateTime{} = datetime -> datetime |> DateTime.to_date() |> is_today?()
      _ -> false
    end
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
    order_dot: %{
      unconfirmed: "bg-yellow-400",
      confirmed: "bg-green-400",
      in_progress: "bg-indigo-400",
      ready: "bg-green-400",
      delivered: "bg-green-400",
      completed: "bg-green-400",
      cancelled: "bg-red-400",
      default: "bg-slate-400"
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
  def order_dot_status_bg(status), do: status_bg(status, "order_dot")

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

  defp normalize_datetime(nil, _timezone), do: nil

  defp normalize_datetime(%Date{} = date, _timezone), do: date

  defp normalize_datetime(%NaiveDateTime{} = naive, timezone) when is_binary(timezone) do
    case DateTime.from_naive(naive, "Etc/UTC") do
      {:ok, datetime} -> normalize_datetime(datetime, timezone)
      _ -> naive
    end
  end

  defp normalize_datetime(%NaiveDateTime{} = naive, _timezone), do: naive

  defp normalize_datetime(%DateTime{} = datetime, timezone) when is_binary(timezone) do
    case DateTime.shift_zone(datetime, timezone) do
      {:ok, shifted} -> shifted
      _ -> datetime
    end
  end

  defp normalize_datetime(%DateTime{} = datetime, _timezone), do: datetime

  defp format_pattern(pattern, _default) when is_binary(pattern), do: pattern
  defp format_pattern(:short, :date), do: "%m/%d"
  defp format_pattern(:medium, :date), do: "%b %d, %Y"
  defp format_pattern(:long, :date), do: "%B %d, %Y"
  defp format_pattern(:iso, :date), do: "%Y-%m-%d"
  defp format_pattern(:short, :datetime), do: "%m/%d %H:%M"
  defp format_pattern(:medium, :datetime), do: "%b %d, %Y %H:%M"
  defp format_pattern(:long, :datetime), do: "%B %d, %Y %H:%M"
  defp format_pattern(:iso, :datetime), do: "%Y-%m-%dT%H:%M:%S"
  defp format_pattern(_, :date), do: "%b %d, %Y"
  defp format_pattern(_, :datetime), do: "%b %d, %Y %H:%M"
end
