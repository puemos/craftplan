defmodule Microcraft.Types.Unit do
  @moduledoc """
  Represents measurement units with conversion and formatting capabilities.
  Supports gram, milliliter, and piece units with appropriate abbreviations.
  """
  use Ash.Type.Enum, values: [:gram, :milliliter, :piece]

  @unit_abbreviations %{
    kilogram: "kg",
    gram: "g",
    liter: "l",
    milliliter: "ml",
    piece: "pc"
  }

  @singular_names %{
    gram: "gram",
    milliliter: "milliliter",
    piece: "piece"
  }

  @plural_names %{
    gram: "grams",
    milliliter: "milliliters",
    piece: "pieces"
  }

  @doc """
  Returns the formatted string for a unit with its value.
  Handles unit conversions where appropriate (e.g., g to kg when value >= 1000).
  Also provides more readable formats for small and large quantities.
  """
  # Gram special cases
  def abbreviation(:gram, value) when value >= 1000 do
    kg_value = value / 1000
    formatted = format_number(kg_value)
    "#{formatted} #{if kg_value == 1, do: "kg", else: "kgs"}"
  end

  def abbreviation(:gram, value) when value <= -1000 do
    kg_value = value / 1000
    formatted = format_number(kg_value)
    "#{formatted} #{if kg_value == -1, do: "kg", else: "kgs"}"
  end

  def abbreviation(:gram, value) when value < 1 and value > 0 do
    mg_value = value * 1000
    formatted = format_number(mg_value)
    "#{formatted} #{if mg_value == 1, do: "milligram", else: "milligrams"}"
  end

  def abbreviation(:gram, value) when value > -1 and value < 0 do
    mg_value = value * 1000
    formatted = format_number(mg_value)
    "#{formatted} #{if mg_value == -1, do: "milligram", else: "milligrams"}"
  end

  def abbreviation(:gram, 1), do: "1 #{@singular_names.gram}"
  def abbreviation(:gram, -1), do: "-1 #{@singular_names.gram}"
  def abbreviation(:gram, value) when is_integer(value), do: "#{value} #{@plural_names.gram}"
  def abbreviation(:gram, value), do: "#{format_number(value)}#{@unit_abbreviations.gram}"

  # Milliliter special cases
  def abbreviation(:milliliter, value) when value >= 1000 do
    l_value = value / 1000
    formatted = format_number(l_value)
    "#{formatted} #{if l_value == 1, do: "liter", else: "liters"}"
  end

  def abbreviation(:milliliter, value) when value <= -1000 do
    l_value = value / 1000
    formatted = format_number(l_value)
    "#{formatted} #{if l_value == -1, do: "liter", else: "liters"}"
  end

  def abbreviation(:milliliter, value) when value < 1 and value > 0 do
    "#{format_number(value * 1000)} microliters"
  end

  def abbreviation(:milliliter, value) when value > -1 and value < 0 do
    "#{format_number(value * 1000)} microliters"
  end

  def abbreviation(:milliliter, 1), do: "1 #{@singular_names.milliliter}"
  def abbreviation(:milliliter, -1), do: "-1 #{@singular_names.milliliter}"

  def abbreviation(:milliliter, value) when is_integer(value), do: "#{value} #{@plural_names.milliliter}"

  def abbreviation(:milliliter, value), do: "#{format_number(value)}#{@unit_abbreviations.milliliter}"

  # Piece special cases
  def abbreviation(:piece, 0), do: "no pieces"
  def abbreviation(:piece, 1), do: "1 #{@singular_names.piece}"
  def abbreviation(:piece, -1), do: "-1 #{@singular_names.piece}"
  def abbreviation(:piece, value), do: "#{value} #{@plural_names.piece}"

  @doc """
  Returns just the abbreviation for a unit.
  """
  def abbreviation(unit), do: @unit_abbreviations[unit]

  # Helper function to format numbers nicely
  defp format_number(value) when is_integer(value), do: "#{value}"
  defp format_number(value) when value == trunc(value), do: "#{trunc(value)}"
  defp format_number(value), do: :erlang.float_to_binary(value, decimals: 1)
end
