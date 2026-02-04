defmodule CraftplanWeb.HtmlHelpersTest do
  use ExUnit.Case, async: true

  alias CraftplanWeb.HtmlHelpers

  describe "format_date/2" do
    test "returns medium format by default" do
      assert HtmlHelpers.format_date(~D[2024-04-12]) == "Apr 12, 2024"
    end

    test "supports datetime inputs with timezone shift" do
      datetime = ~U[2024-04-12 18:30:00Z]

      assert HtmlHelpers.format_date(datetime, timezone: "America/New_York", format: :long) ==
               "April 12, 2024 14:30"
    end

    test "returns empty string for nil values" do
      assert HtmlHelpers.format_date(nil) == ""
    end
  end

  describe "format_day_name/2" do
    test "renders short weekday names" do
      assert HtmlHelpers.format_day_name(~D[2024-04-15]) == "Mon"
    end

    test "renders long weekday names" do
      assert HtmlHelpers.format_day_name(~D[2024-04-15], style: :long) == "Monday"
    end

    test "respects timezone shifts" do
      datetime = ~U[2024-04-12 23:30:00Z]

      assert HtmlHelpers.format_day_name(datetime, timezone: "Asia/Tokyo") == "Sat"
    end
  end

  describe "format_time/2" do
    test "formats with timezone" do
      datetime = ~U[2024-04-12 18:30:00Z]

      assert HtmlHelpers.format_time(datetime, "America/Los_Angeles") == "11:30 AM"
    end

    test "supports custom format strings" do
      datetime = ~U[2024-04-12 18:30:00Z]

      assert HtmlHelpers.format_time(datetime, format: "%H:%M", timezone: "Etc/UTC") == "18:30"
    end

    test "returns empty string for nil" do
      assert HtmlHelpers.format_time(nil, "America/New_York") == ""
    end
  end

  describe "date_range/2" do
    test "defaults to seven days" do
      range = HtmlHelpers.date_range(~D[2024-04-01])

      assert Enum.count(range) == 7
      assert List.first(range) == ~D[2024-04-01]
      assert List.last(range) == ~D[2024-04-07]
    end

    test "supports custom length" do
      range = HtmlHelpers.date_range(~D[2024-04-01], days: 3)
      assert range == [~D[2024-04-01], ~D[2024-04-02], ~D[2024-04-03]]
    end

    test "supports until option" do
      range = HtmlHelpers.date_range(~D[2024-04-01], until: ~D[2024-04-04])
      assert range == [~D[2024-04-01], ~D[2024-04-02], ~D[2024-04-03], ~D[2024-04-04]]
    end
  end

  describe "format_duration/2" do
    test "formats compact durations" do
      assert HtmlHelpers.format_duration(3661) == "1h 1m 1s"
    end

    test "formats long durations" do
      assert HtmlHelpers.format_duration(3661, style: :long) == "1 hour 1 minute 1 second"
    end

    test "formats clock style" do
      assert HtmlHelpers.format_duration(Time.from_iso8601!("01:30:05"), style: :clock) ==
               "01:30:05"
    end
  end

  describe "format_currency/3" do
    test "returns Money struct by default" do
      money = HtmlHelpers.format_currency(:USD, Decimal.new("123"))

      assert match?(%Money{}, money)
      assert money.currency == :USD
      assert money.amount == Decimal.new("123")
    end

    test "supports integers and string formatting" do
      assert HtmlHelpers.format_currency(:USD, 25, format: :string) == "$25.00"
    end

    test "handles nil values" do
      assert HtmlHelpers.format_currency(:USD, nil, format: :string) == "$0.00"
    end
  end

  describe "format_short_date/2" do
    test "defaults to day of month" do
      assert HtmlHelpers.format_short_date(~D[2024-04-09]) == "09"
    end

    test "allows custom missing display" do
      assert HtmlHelpers.format_short_date(nil, missing: "—") == "—"
    end
  end

  describe "is_today?/2" do
    test "supports dates" do
      assert HtmlHelpers.is_today?(Date.utc_today())
    end

    test "supports datetimes with timezone" do
      {:ok, datetime} = DateTime.new(Date.utc_today(), ~T[12:00:00], "Etc/UTC")
      assert HtmlHelpers.is_today?(datetime, "Etc/UTC")
    end

    test "supports naive datetimes" do
      {:ok, naive} = NaiveDateTime.new(Date.utc_today(), ~T[12:00:00])
      assert HtmlHelpers.is_today?(naive)
    end
  end

  describe "format_percentage/2" do
    test "rounds to whole numbers by default" do
      assert HtmlHelpers.format_percentage(Decimal.new("0.756")) == Decimal.new("76")
    end

    test "handles exact percentages" do
      assert HtmlHelpers.format_percentage(Decimal.new("0.50")) == Decimal.new("50")
    end

    test "handles 0%" do
      assert HtmlHelpers.format_percentage(Decimal.new("0")) == Decimal.new("0")
    end

    test "handles 100%" do
      assert HtmlHelpers.format_percentage(Decimal.new("1")) == Decimal.new("100")
    end

    test "handles nil input" do
      assert HtmlHelpers.format_percentage(nil) == Decimal.new("0")
    end

    test "handles integer input" do
      assert HtmlHelpers.format_percentage(1) == Decimal.new("100")
    end

    test "supports custom decimal places" do
      assert HtmlHelpers.format_percentage(Decimal.new("0.7567"), places: 2) == Decimal.new("75.67")
    end

    test "rounds up correctly" do
      assert HtmlHelpers.format_percentage(Decimal.new("0.995")) == Decimal.new("100")
    end

    test "rounds down correctly" do
      assert HtmlHelpers.format_percentage(Decimal.new("0.994")) == Decimal.new("99")
    end
  end
end
