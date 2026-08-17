defmodule CraftplanWeb.Plugs.ApiKeyAuthTest do
  use CraftplanWeb.ConnCase, async: true

  alias Craftplan.Accounts
  alias CraftplanWeb.Plugs.ApiKeyAuth

  defp create_api_key!(scopes) do
    admin = Craftplan.DataCase.admin_actor()

    {:ok, api_key} =
      Accounts.create_api_key(%{name: "test-key", scopes: scopes}, actor: admin)

    {Map.get(api_key, :__raw_key__), api_key, admin}
  end

  describe "call/2" do
    test "sets an already assigned current_user as the Ash actor", %{conn: conn} do
      admin = Craftplan.DataCase.admin_actor()
      conn = Plug.Conn.assign(conn, :current_user, admin)
      Process.put(:api_key_scopes, %{"stale" => ["read"]})

      result = ApiKeyAuth.call(conn, [])

      assert result.assigns[:current_user] == admin
      assert Ash.PlugHelpers.get_actor(result) == admin
      refute Process.get(:api_key_scopes)
      refute Map.has_key?(result.assigns, :current_api_key)
    end

    test "authenticates valid cpk_ bearer token", %{conn: conn} do
      {raw_key, api_key, admin} = create_api_key!(%{"products" => ["read"]})

      result =
        conn
        |> put_req_header("authorization", "Bearer #{raw_key}")
        |> ApiKeyAuth.call([])

      assert result.assigns[:current_user].id == admin.id
      assert result.assigns[:current_api_key].id == api_key.id
      assert Ash.PlugHelpers.get_actor(result).id == admin.id
    end

    test "ignores non-cpk_ bearer tokens", %{conn: conn} do
      result =
        conn
        |> put_req_header("authorization", "Bearer some-jwt-token")
        |> ApiKeyAuth.call([])

      refute Map.has_key?(result.assigns, :current_user)
      refute Map.has_key?(result.assigns, :current_api_key)
    end

    test "ignores missing authorization header", %{conn: conn} do
      result = ApiKeyAuth.call(conn, [])

      refute Map.has_key?(result.assigns, :current_user)
      refute Map.has_key?(result.assigns, :current_api_key)
    end

    test "assigns current_user and current_api_key on success", %{conn: conn} do
      {raw_key, _api_key, _admin} = create_api_key!(%{"products" => ["read"]})

      result =
        conn
        |> put_req_header("authorization", "Bearer #{raw_key}")
        |> ApiKeyAuth.call([])

      assert %Craftplan.Accounts.User{} = result.assigns[:current_user]
      assert result.assigns[:current_api_key].name == "test-key"
    end

    test "stores scopes in process dictionary", %{conn: conn} do
      scopes = %{"products" => ["read", "write"]}
      {raw_key, _api_key, _admin} = create_api_key!(scopes)

      conn
      |> put_req_header("authorization", "Bearer #{raw_key}")
      |> ApiKeyAuth.call([])

      assert Process.get(:api_key_scopes) == scopes
    end
  end
end
