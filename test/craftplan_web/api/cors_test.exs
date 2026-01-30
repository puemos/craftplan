defmodule CraftplanWeb.Api.CorsTest do
  use CraftplanWeb.ConnCase, async: true

  @origin "https://docs.example.com"

  defp preflight(conn, path) do
    conn
    |> put_req_header("origin", @origin)
    |> put_req_header("access-control-request-method", "GET")
    |> put_req_header("access-control-request-headers", "authorization, content-type")
    |> dispatch(CraftplanWeb.Endpoint, :options, path)
  end

  describe "CORS preflight" do
    test "OPTIONS /api/json/products returns CORS headers", %{conn: conn} do
      resp = preflight(conn, "/api/json/products")

      assert get_resp_header(resp, "access-control-allow-origin") != []
      assert get_resp_header(resp, "access-control-allow-methods") != []
      assert get_resp_header(resp, "access-control-allow-headers") != []
    end
  end

  describe "CORS simple request" do
    test "GET /api/json/products includes access-control-allow-origin", %{conn: conn} do
      resp =
        conn
        |> put_req_header("origin", @origin)
        |> get("/api/json/products")

      assert get_resp_header(resp, "access-control-allow-origin") != []
    end
  end
end
