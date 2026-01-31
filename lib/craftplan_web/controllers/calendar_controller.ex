defmodule CraftplanWeb.CalendarController do
  use CraftplanWeb, :controller

  alias Craftplan.Calendar.FeedGenerator

  def feed(conn, _params) do
    actor = conn.assigns[:current_user]
    ics = FeedGenerator.generate(actor)

    conn
    |> put_resp_content_type("text/calendar")
    |> put_resp_header("content-disposition", ~s(inline; filename="craftplan.ics"))
    |> send_resp(200, ics)
  end
end
