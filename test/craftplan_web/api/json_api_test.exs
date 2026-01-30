defmodule CraftplanWeb.Api.JsonApiTest do
  use CraftplanWeb.ConnCase, async: true

  alias Craftplan.Accounts
  alias Craftplan.Test.Factory

  defp create_api_key!(scopes) do
    admin = Craftplan.DataCase.admin_actor()

    {:ok, api_key} =
      Accounts.create_api_key(%{name: "test-key", scopes: scopes}, actor: admin)

    {Map.get(api_key, :__raw_key__), api_key, admin}
  end

  defp api_conn(conn, raw_key) do
    conn
    |> put_req_header("authorization", "Bearer #{raw_key}")
    |> put_req_header("content-type", "application/vnd.api+json")
  end

  describe "GET /api/json/products" do
    test "returns product list with valid scoped key", %{conn: conn} do
      {raw_key, _api_key, admin} =
        create_api_key!(%{"products" => ["read"]})

      Factory.create_product!(%{name: "Widget"}, admin)

      resp =
        conn
        |> api_conn(raw_key)
        |> get("/api/json/products")
        |> json_response(200)

      assert is_list(resp["data"])
      assert length(resp["data"]) >= 1

      names = Enum.map(resp["data"], & &1["attributes"]["name"])
      assert "Widget" in names
    end

    test "returns empty data when key lacks products read scope", %{conn: conn} do
      {raw_key, _api_key, admin} =
        create_api_key!(%{"orders" => ["read"]})

      # Create a product that should NOT be visible
      Factory.create_product!(%{name: "Hidden"}, admin)

      resp =
        conn
        |> api_conn(raw_key)
        |> get("/api/json/products")
        |> json_response(200)

      # Ash policy filtering returns empty data instead of 403 for reads
      assert resp["data"] == []
    end

    test "returns empty data when no products exist", %{conn: conn} do
      {raw_key, _api_key, _admin} =
        create_api_key!(%{"products" => ["read"]})

      resp =
        conn
        |> api_conn(raw_key)
        |> get("/api/json/products")
        |> json_response(200)

      assert resp["data"] == []
    end
  end

  describe "GET /api/json/products/:id" do
    test "returns single product", %{conn: conn} do
      {raw_key, _api_key, admin} =
        create_api_key!(%{"products" => ["read"]})

      product = Factory.create_product!(%{name: "Single Widget"}, admin)

      resp =
        conn
        |> api_conn(raw_key)
        |> get("/api/json/products/#{product.id}")
        |> json_response(200)

      assert resp["data"]["id"] == product.id
      assert resp["data"]["attributes"]["name"] == "Single Widget"
    end
  end

  describe "GET /api/json/customers" do
    test "returns customer list with scoped key", %{conn: conn} do
      {raw_key, _api_key, admin} =
        create_api_key!(%{"customers" => ["read"]})

      Factory.create_customer!(%{first_name: "Alice", last_name: "Smith"}, admin)

      resp =
        conn
        |> api_conn(raw_key)
        |> get("/api/json/customers")
        |> json_response(200)

      assert is_list(resp["data"])
      assert length(resp["data"]) >= 1
    end
  end

  describe "GET /api/json/orders" do
    test "returns empty data without orders scope", %{conn: conn} do
      {raw_key, _api_key, _admin} =
        create_api_key!(%{"products" => ["read"]})

      resp =
        conn
        |> api_conn(raw_key)
        |> get("/api/json/orders")
        |> json_response(200)

      # Ash policy filtering returns empty data for unauthorized reads
      assert resp["data"] == []
    end
  end

  describe "scope enforcement" do
    test "scoped key can access allowed resources but not others", %{conn: conn} do
      {raw_key, _api_key, admin} =
        create_api_key!(%{"products" => ["read"]})

      Factory.create_product!(%{name: "Accessible"}, admin)
      Factory.create_customer!(%{first_name: "Hidden", last_name: "Customer"}, admin)

      # Products should be accessible
      products_resp =
        conn
        |> api_conn(raw_key)
        |> get("/api/json/products")
        |> json_response(200)

      assert length(products_resp["data"]) >= 1

      # Customers should be filtered out (no customers scope)
      customers_resp =
        conn
        |> api_conn(raw_key)
        |> get("/api/json/customers")
        |> json_response(200)

      assert customers_resp["data"] == []
    end
  end

  describe "revoked key" do
    test "revoked key loses access to restricted resources", %{conn: conn} do
      {raw_key, api_key, admin} =
        create_api_key!(%{"customers" => ["read"]})

      Factory.create_customer!(%{first_name: "Secret", last_name: "Client"}, admin)

      # Verify key works before revocation (customers require staff/admin role)
      resp =
        conn
        |> api_conn(raw_key)
        |> get("/api/json/customers")
        |> json_response(200)

      assert length(resp["data"]) >= 1

      # Revoke the key
      {:ok, _revoked} = Accounts.revoke_api_key(api_key, actor: admin)

      # After revocation, the plug fails to authenticate —
      # request proceeds without actor, policies filter restricted results
      revoked_resp =
        conn
        |> api_conn(raw_key)
        |> get("/api/json/customers")
        |> json_response(200)

      assert revoked_resp["data"] == []
    end
  end
end
