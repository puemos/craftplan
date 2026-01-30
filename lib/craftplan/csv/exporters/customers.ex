defmodule Craftplan.CSV.Exporters.Customers do
  @moduledoc false

  alias NimbleCSV.RFC4180, as: CSV

  @headers ["reference", "type", "first_name", "last_name", "email", "phone"]

  def export(actor) do
    customers = Craftplan.CRM.list_customers!(%{}, actor: actor)

    rows =
      Enum.map(customers, fn c ->
        [
          c.reference || "",
          to_string(c.type || ""),
          c.first_name || "",
          c.last_name || "",
          c.email || "",
          c.phone || ""
        ]
      end)

    [@headers | rows] |> CSV.dump_to_iodata() |> IO.iodata_to_binary()
  end
end
