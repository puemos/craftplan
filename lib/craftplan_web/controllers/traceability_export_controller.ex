defmodule CraftplanWeb.TraceabilityExportController do
  use CraftplanWeb, :controller

  alias Craftplan.CSV.Exporters.Traceability, as: TraceabilityCSV
  alias Craftplan.Traceability

  def show(conn, %{"q" => query} = params) do
    actor = conn.assigns[:current_user]

    if is_nil(actor) do
      conn
      |> put_flash(:error, "You must be signed in")
      |> redirect(to: ~p"/sign-in")
    else
      mode = parse_mode(Map.get(params, "mode"))
      result = Traceability.lookup(query, actor: actor, mode: mode)
      filename = "traceability_#{safe_filename(query)}_#{Date.to_iso8601(Date.utc_today())}.csv"

      conn
      |> put_resp_content_type("text/csv")
      |> put_resp_header("content-disposition", ~s(attachment; filename="#{filename}"))
      |> send_resp(200, TraceabilityCSV.export(result))
    end
  end

  def show(conn, _params) do
    conn
    |> put_flash(:error, "Enter a lot or batch code before exporting")
    |> redirect(to: ~p"/manage/production/traceability")
  end

  defp parse_mode("forward"), do: :forward
  defp parse_mode("backward"), do: :backward
  defp parse_mode(_mode), do: :recall

  defp safe_filename(query) do
    query
    |> String.replace(~r/[^A-Za-z0-9_-]+/, "-")
    |> String.trim("-")
  end
end
