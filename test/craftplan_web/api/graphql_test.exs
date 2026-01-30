defmodule CraftplanWeb.Api.GraphqlTest do
  use CraftplanWeb.ConnCase, async: true

  alias Craftplan.Accounts
  alias Craftplan.Test.Factory

  defp create_api_key!(scopes) do
    admin = Craftplan.DataCase.admin_actor()

    {:ok, api_key} =
      Accounts.create_api_key(%{name: "test-key", scopes: scopes}, actor: admin)

    {Map.get(api_key, :__raw_key__), api_key, admin}
  end

  defp graphql(conn, raw_key, query, variables \\ %{}) do
    conn
    |> put_req_header("authorization", "Bearer #{raw_key}")
    |> put_req_header("content-type", "application/json")
    |> post("/api/graphql", Jason.encode!(%{"query" => query, "variables" => variables}))
    |> json_response(200)
  end

  defp graphql_unauth(conn, query) do
    conn
    |> put_req_header("content-type", "application/json")
    |> post("/api/graphql", Jason.encode!(%{"query" => query}))
    |> json_response(200)
  end

  describe "queries" do
    test "listProducts returns data with read scope", %{conn: conn} do
      {raw_key, _api_key, admin} =
        create_api_key!(%{"products" => ["read"]})

      Factory.create_product!(%{name: "GQL Widget"}, admin)

      query = """
      {
        listProducts {
          results {
            id
            name
          }
        }
      }
      """

      resp = graphql(conn, raw_key, query)

      assert is_nil(resp["errors"])
      results = get_in(resp, ["data", "listProducts", "results"])
      assert is_list(results)
      assert length(results) >= 1

      names = Enum.map(results, & &1["name"])
      assert "GQL Widget" in names
    end

    test "getProduct by id works", %{conn: conn} do
      {raw_key, _api_key, admin} =
        create_api_key!(%{"products" => ["read"]})

      product = Factory.create_product!(%{name: "GQL Single"}, admin)

      query = """
      query GetProduct($id: ID!) {
        getProduct(id: $id) {
          id
          name
        }
      }
      """

      resp = graphql(conn, raw_key, query, %{"id" => product.id})

      assert is_nil(resp["errors"])
      assert get_in(resp, ["data", "getProduct", "name"]) == "GQL Single"
    end

    test "key without scope sees empty products list", %{conn: conn} do
      {raw_key, _api_key, admin} =
        create_api_key!(%{"orders" => ["read"]})

      Factory.create_product!(%{name: "Hidden GQL"}, admin)

      query = """
      {
        listProducts {
          results {
            id
          }
        }
      }
      """

      resp = graphql(conn, raw_key, query)

      # Ash policy filtering returns empty results for unauthorized reads
      results = get_in(resp, ["data", "listProducts", "results"])
      assert results == []
    end
  end

  describe "scope enforcement" do
    test "scoped key grants access to listed resources only", %{conn: conn} do
      {raw_key, _api_key, admin} =
        create_api_key!(%{"products" => ["read"], "customers" => ["read"]})

      Factory.create_product!(%{name: "GQL Visible"}, admin)

      products_query = """
      {
        listProducts {
          results {
            id
            name
          }
        }
      }
      """

      resp = graphql(conn, raw_key, products_query)

      assert is_nil(resp["errors"])
      results = get_in(resp, ["data", "listProducts", "results"])
      assert length(results) >= 1
    end
  end

  describe "authentication" do
    test "unauthenticated request can see public products", %{conn: conn} do
      # Products with selling_availability != :off are publicly readable
      admin = Craftplan.DataCase.admin_actor()
      Factory.create_product!(%{name: "Public GQL"}, admin)

      query = """
      {
        listProducts {
          results {
            id
            name
          }
        }
      }
      """

      resp = graphql_unauth(conn, query)

      # Without actor, product public read policy allows active/available products
      results = get_in(resp, ["data", "listProducts", "results"])
      assert is_list(results)
    end

    test "unauthenticated request cannot see restricted resources", %{conn: conn} do
      admin = Craftplan.DataCase.admin_actor()
      Factory.create_customer!(%{first_name: "Private", last_name: "GQL"}, admin)

      query = """
      {
        listCustomers {
          results {
            id
          }
        }
      }
      """

      resp = graphql_unauth(conn, query)

      # Customers require staff/admin role - filtered out without actor
      results = get_in(resp, ["data", "listCustomers", "results"])
      assert results == []
    end
  end
end
