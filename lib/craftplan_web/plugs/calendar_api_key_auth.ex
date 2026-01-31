defmodule CraftplanWeb.Plugs.CalendarApiKeyAuth do
  @moduledoc """
  Plug that authenticates calendar feed requests using an API key in the `?key=` query param.

  Calendar apps (Google Calendar, Apple Calendar) cannot send Authorization headers,
  so the API key is passed as a query parameter instead.
  """
  @behaviour Plug

  import Plug.Conn

  alias Craftplan.Accounts

  @impl true
  def init(opts), do: opts

  @impl true
  def call(conn, _opts) do
    case extract_query_key(conn) do
      {:ok, raw_key} -> authenticate(conn, raw_key)
      :error -> unauthorized(conn)
    end
  end

  defp extract_query_key(conn) do
    case conn.query_params do
      %{"key" => "cpk_" <> _ = raw_key} -> {:ok, raw_key}
      _ -> :error
    end
  end

  defp authenticate(conn, raw_key) do
    key_hash = :sha256 |> :crypto.hash(raw_key) |> Base.encode16(case: :lower)

    with {:ok, api_key} <- Accounts.authenticate_api_key(%{key_hash: key_hash}),
         {:ok, user} <- Ash.get(Craftplan.Accounts.User, api_key.user_id, authorize?: false) do
      Process.put(:api_key_scopes, api_key.scopes)

      Task.start(fn ->
        Accounts.touch_api_key_last_used(api_key, authorize?: false)
      end)

      conn
      |> assign(:current_user, user)
      |> assign(:current_api_key, api_key)
      |> Ash.PlugHelpers.set_actor(user)
    else
      _ -> unauthorized(conn)
    end
  end

  defp unauthorized(conn) do
    conn
    |> put_resp_content_type("text/plain")
    |> send_resp(401, "Unauthorized")
    |> halt()
  end
end
