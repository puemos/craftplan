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

  test "kcal displays correctly without conversion" do
    assert Unit.abbreviation(:kcal, 100) == "100 kcal"
    assert Unit.abbreviation(:kcal, 1500) == "1500 kcal"
    assert Unit.abbreviation(:kcal, 2000) == "2000 kcal"
    assert Unit.abbreviation(:kcal, 150.5) == "150.5 kcal"
  end

  test "milligram displays correctly without conversion" do
    assert Unit.abbreviation(:milligram, 100) == "100 mg"
    assert Unit.abbreviation(:milligram, 1500) == "1500 mg"
    assert Unit.abbreviation(:milligram, 0.5) == "0.5 mg"
  end

  test "percent displays correctly" do
    assert Unit.abbreviation(:percent, 100) == "100%"
    assert Unit.abbreviation(:percent, 15) == "15%"
    assert Unit.abbreviation(:percent, 2.5) == "2.5%"
  end

  test "single-argument abbreviation returns unit symbol" do
    assert Unit.abbreviation(:gram) == "g"
    assert Unit.abbreviation(:milliliter) == "ml"
    assert Unit.abbreviation(:piece) == "pc"
    assert Unit.abbreviation(:kcal) == "kcal"
    assert Unit.abbreviation(:milligram) == "mg"
    assert Unit.abbreviation(:percent) == "%"
  end
end
