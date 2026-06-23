defmodule Craftplan.BottleImport.PhoneNormalizer do
  @moduledoc false

  @spec normalize(String.t() | nil) :: {:ok, String.t()} | :error
  def normalize(nil), do: :error

  def normalize(raw) when is_binary(raw) do
    digits = String.replace(raw, ~r/\D/, "")
    if String.length(digits) >= 10, do: {:ok, digits}, else: :error
  end
end
