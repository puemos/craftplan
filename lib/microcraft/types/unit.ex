defmodule Microcraft.Types.Unit do
  @moduledoc false
  use Ash.Type.Enum, values: [:gram, :milliliter, :piece]

  @unit_abbreviations %{
    kilogram: "kg",
    gram: "g",
    liter: "l",
    milliliter: "ml",
    piece: "p"
  }

  def abbreviation(:gram, value) when value >= 1000, do: "#{value / 1000}#{@unit_abbreviations.kilogram}"

  def abbreviation(:gram, value), do: "#{value}#{@unit_abbreviations.gram}"

  def abbreviation(:milliliter, value) when value >= 1000, do: "#{value / 1000}#{@unit_abbreviations.liter}"

  def abbreviation(:milliliter, value), do: "#{value}#{@unit_abbreviations.milliliter}"
  def abbreviation(:piece, value), do: "#{value}#{@unit_abbreviations.piece}"
  def abbreviation(unit), do: @unit_abbreviations[unit]
end
