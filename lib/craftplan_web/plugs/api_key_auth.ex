defmodule CraftplanWeb.Plugs.ApiKeyAuth do
  @moduledoc """
  Plug that authenticates requests using API keys (`cpk_` prefixed Bearer tokens).

  Skips if a current_user is already assigned (e.g. from JWT auth).
  On success, assigns `current_user` and `current_api_key` and stores
  scopes in process dictionary for policy checks.
  """
  @behaviour Plug

  import Plug.Conn

  alias Craftplan.Accounts

  @impl true
  def init(opts), do: opts

  @impl true
  def call(conn, _opts) do
    if conn.assigns[:current_user] do
      conn
    else
      authenticate_api_key(conn)
    end
  end

  defp authenticate_api_key(conn) do
    with {:ok, raw_key} <- extract_bearer_token(conn),
         true <- String.starts_with?(raw_key, "cpk_"),
         key_hash = :sha256 |> :crypto.hash(raw_key) |> Base.encode16(case: :lower),
         {:ok, api_key} <- Accounts.authenticate_api_key(%{key_hash: key_hash}),
         {:ok, user} <- Ash.get(Craftplan.Accounts.User, api_key.user_id, authorize?: false) do
      # Store scopes in process dictionary for ApiScopeCheck policy
      Process.put(:api_key_scopes, api_key.scopes)

      # Touch last_used_at asynchronously
      Task.start(fn ->
        Accounts.touch_api_key_last_used(api_key, authorize?: false)
      end)

      conn
      |> assign(:current_user, user)
      |> assign(:current_api_key, api_key)
      |> Ash.PlugHelpers.set_actor(user)
    else
      _ -> conn
    end
  end

  defp extract_bearer_token(conn) do
    case get_req_header(conn, "authorization") do
      ["Bearer " <> token] -> {:ok, token}
      _ -> :error
    end
  end
end
