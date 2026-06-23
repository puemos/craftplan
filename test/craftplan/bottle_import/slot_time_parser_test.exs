defmodule Craftplan.BottleImport.SlotTimeParserTest do
  use ExUnit.Case, async: true

  alias Craftplan.BottleImport.SlotTimeParser

  describe "parse/2" do
    test "parses an EST slot time (winter, no DST)" do
      # 05:00 EST = 10:00 UTC
      assert SlotTimeParser.parse(~D[2026-01-13], "1/13 05:00AM - 1/13 12:00PM") ==
               {:ok, ~U[2026-01-13 10:00:00Z]}
    end

    test "parses an EDT slot time (summer, DST in effect)" do
      # 05:00 EDT = 09:00 UTC
      assert SlotTimeParser.parse(~D[2026-06-15], "6/15 05:00AM - 6/15 12:00PM") ==
               {:ok, ~U[2026-06-15 09:00:00Z]}
    end

    test "parses a PM time" do
      assert SlotTimeParser.parse(~D[2026-01-13], "1/13 02:30PM - 1/13 07:00PM") ==
               {:ok, ~U[2026-01-13 19:30:00Z]}
    end

    test "returns error for unrecognized format" do
      assert {:error, _} = SlotTimeParser.parse(~D[2026-01-13], "anytime")
    end

    test "returns error for nil time string" do
      assert {:error, _} = SlotTimeParser.parse(~D[2026-01-13], nil)
    end
  end
end
