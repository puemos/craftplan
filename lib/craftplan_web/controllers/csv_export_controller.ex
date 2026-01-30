defmodule CraftplanWeb.CSVExportController do
  use CraftplanWeb, :controller

  @exporters %{
    "orders" => Craftplan.CSV.Exporters.Orders,
    "customers" => Craftplan.CSV.Exporters.Customers,
    "movements" => Craftplan.CSV.Exporters.Movements
  }

  def export(conn, %{"entity" => entity}) do
    case Map.fetch(@exporters, entity) do
      {:ok, exporter} ->
        actor = conn.assigns[:current_user]
        csv = exporter.export(actor)
        filename = "#{entity}_#{Date.to_iso8601(Date.utc_today())}.csv"

        conn
        |> put_resp_content_type("text/csv")
        |> put_resp_header("content-disposition", ~s(attachment; filename="#{filename}"))
        |> send_resp(200, csv)

      :error ->
        conn
        |> put_flash(:error, "Unknown export entity")
        |> redirect(to: ~p"/manage/settings/csv")
    end
  end
end
