defmodule Craftplan.BottleImport.NameParser do
  @moduledoc false

  @placeholder "-"

  @spec parse(String.t() | nil) :: %{
          first_name: String.t(),
          last_name: String.t(),
          is_mononym: boolean()
        }
  def parse(nil), do: %{first_name: @placeholder, last_name: @placeholder, is_mononym: true}

  def parse(full) when is_binary(full) do
    case full |> String.trim() |> String.split() do
      [] -> %{first_name: @placeholder, last_name: @placeholder, is_mononym: true}
      [only] -> %{first_name: @placeholder, last_name: only, is_mononym: true}
      [first | rest] -> %{first_name: first, last_name: Enum.join(rest, " "), is_mononym: false}
    end
  end
end
