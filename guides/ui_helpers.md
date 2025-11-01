# UI Helper Catalogue

The UI helpers live in `CraftplanWeb.HtmlHelpers` and are imported into LiveViews,
components, and templates via `use CraftplanWeb, :live_view` / `:html`. They provide
consistent formatting for dates, times, durations, and currency values.

## Date & Time Helpers

### `format_date/2`

- **Purpose:** Render `Date`, `NaiveDateTime`, or `DateTime` values using
  common presets or custom `Calendar.strftime/2` patterns.
- **Arguments:**
  - Value (`Date | NaiveDateTime | DateTime | nil`).
  - Options: `:format` (`:short`, `:medium`, `:long`, `:iso` or custom pattern),
    `:timezone` (string).
- **Example:** `format_date(~U[2024-04-12 18:00:00Z], timezone: "America/Chicago", format: :long)
#=> "April 12, 2024 13:00"`

### `format_short_date/2`

- **Purpose:** Compact date output for table headers and badges.
- **Arguments:**
  - Value plus optional `:timezone`, `:format` (defaults to `%d`), and
    `:missing` fallback (`"N/A"` by default).
- **Example:** `format_short_date(~D[2024-04-09]) #=> "09"`
  `format_short_date(nil, missing: "—") #=> "—"`

### `format_day_name/2`

- **Purpose:** Weekday labels for schedule strips.
- **Arguments:** Value and options (`:style` `:short | :long`, `:timezone`).
- **Example:** `format_day_name(~D[2024-04-15]) #=> "Mon"`

### `format_time/2`

- **Purpose:** Time-of-day display with optional timezone shifting.
- **Arguments:** Value plus options (`:format` atom or pattern, `:timezone`).
  Passing a timezone string as the second argument is supported for
  backwards compatibility.
- **Example:** `format_time(~U[2024-04-12 18:30:00Z], "America/Los_Angeles") #=> "11:30 AM"`

### `format_hour/2`

- **Purpose:** 12-hour clock shortcut around `format_time/2`.
- **Arguments:** Value and timezone string (returns `""` when timezone is nil).
- **Example:** `format_hour(~U[2024-04-12 18:30:00Z], "America/New_York") #=> "02:30 PM"`

### `date_range/2`

- **Purpose:** Generate inclusive ranges of dates for calendar/schedule views.
- **Arguments:** Start `Date` plus options `:days`, `:until`, and optional `:step` (defaults to 1).
- **Example:** `date_range(~D[2024-04-01], days: 3) #=> [~D[2024-04-01], ~D[2024-04-02], ~D[2024-04-03]]`

### `is_today?/2`

- **Purpose:** Day comparisons that respect timezone-aware values.
- **Arguments:** Value and optional `:timezone` string.
- **Example:** `is_today?(~U[2024-04-12 23:00:00Z], "Europe/London") #=> true`

## Duration Helpers

### `format_duration/2`

- **Purpose:** Human-friendly durations for production timing.
- **Arguments:** Seconds (integer) or `Time` plus `:style` (`:compact`, `:long`, `:clock`).
- **Example:** `format_duration(3661) #=> "1h 1m 1s"`

## Money & Quantities

### `format_currency/3` and `format_money/3`

- **Purpose:** Convert integers, decimals, floats, strings, or `Money` structs into a
  canonical Money struct, or a formatted string when `format: :string` is provided.
- **Arguments:** Currency atom, amount, optional `Money.to_string!/2` options.
- **Example:** `format_money(:USD, 25, format: :string) #=> "$25.00"`

### `format_amount/2`

- **Purpose:** Combine quantity and unit abbreviations (existing behaviour unchanged).

### `format_percentage/2` and `safe_add/2`

- **Purpose:** Numeric helpers for dashboards; unchanged but listed for completeness.

## Usage Tips

- Always prefer these helpers over manual `Calendar.strftime/2` or ad-hoc Money operations.
- Pass timezone options when rendering `DateTime` values captured in UTC.
- Use `format_short_date/2` with `missing: "—"` for tables that require an explicit empty state.
- When testing, assert against helper output to keep expectations aligned with production formatting.
