defmodule Craftplan.CSV.Exporters.Movements do
  @moduledoc false

  alias NimbleCSV.RFC4180, as: CSV

  @headers ["quantity", "reason", "occurred_at", "material_name", "lot_number"]

  def export(actor) do
    movements =
      Craftplan.Inventory.list_movements!(actor: actor, load: [:material, :lot])

    rows =
      Enum.map(movements, fn m ->
        [
          to_string(m.quantity || "0"),
          m.reason || "",
          format_datetime(m.occurred_at),
          material_name(m),
          lot_number(m)
        ]
      end)

    [@headers | rows] |> CSV.dump_to_iodata() |> IO.iodata_to_binary()
  end

  defp material_name(%{material: %{name: name}}) when is_binary(name), do: name
  defp material_name(_), do: ""

  defp lot_number(%{lot: %{lot_code: code}}) when is_binary(code), do: code
  defp lot_number(_), do: ""

  defp format_datetime(nil), do: ""
  defp format_datetime(%DateTime{} = dt), do: DateTime.to_iso8601(dt)
  defp format_datetime(other), do: to_string(other)
end
