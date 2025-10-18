defmodule Craftplan.Types.UnitTest do
  use ExUnit.Case, async: true

  alias Craftplan.Types.Unit

  test "gram to kg and mg conversions" do
    assert Unit.abbreviation(:gram, 1000) =~ "kg"
    assert Unit.abbreviation(:gram, -2000) =~ "kg"
    assert Unit.abbreviation(:gram, 0.5) =~ "milligram"
    assert Unit.abbreviation(:gram, -0.75) =~ "milligram"
    assert Unit.abbreviation(:gram, 1) =~ "1 gram"
    assert Unit.abbreviation(:gram, 2) =~ "grams"
  end

  test "milliliter to liter and microliters conversions" do
    assert Unit.abbreviation(:milliliter, 1000) =~ "liter"
    assert Unit.abbreviation(:milliliter, -2000) =~ "liter"
    assert Unit.abbreviation(:milliliter, 0.5) =~ "microliters"
    assert Unit.abbreviation(:milliliter, -0.25) =~ "microliters"
    assert Unit.abbreviation(:milliliter, 1) =~ "1 milliliter"
    assert Unit.abbreviation(:milliliter, 2) =~ "milliliters"
  end

  test "piece special cases" do
    assert Unit.abbreviation(:piece, 0) == "no pieces"
    assert Unit.abbreviation(:piece, 1) =~ "1 piece"
    assert Unit.abbreviation(:piece, -1) =~ "-1 piece"
    assert Unit.abbreviation(:piece, 3) =~ "pieces"
  end
end

