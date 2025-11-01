defmodule Craftplan.DecimalHelpers do
  @moduledoc """
  Provides helper functions for working with Decimals.
  """

  alias Decimal, as: D

  @doc """
  Casts a value of any of the supported types into a Decimal.

  Supported types are:
  - `Decimal`
  - `integer`
  - `float` (will be rounded to 4 decimal places)
  - `binary` (string representation of a number, returns 0 if invalid)
  - `nil` (will return `Decimal.new(0)`)
  - any other value that `Decimal.cast/1` can handle.
  """
  def to_decimal(%D{} = d), do: d
  def to_decimal(i) when is_integer(i), do: D.new(i)
  def to_decimal(f) when is_float(f), do: f |> D.from_float() |> D.round(4)
  def to_decimal(s) when is_binary(s) do
    try do
      D.new(s)
    rescue
      _ -> D.new(0)
    end
  end
  def to_decimal(nil), do: D.new(0)

  def to_decimal(other) do
    case D.cast(other) do
      {:ok, d} -> d
      :error -> D.new(0)
    end
  end
end