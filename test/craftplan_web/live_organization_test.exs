defmodule CraftplanWeb.LiveOrganizationTest do
  use ExUnit.Case, async: true

  alias CraftplanWeb.LiveOrganization

  describe "base_path/1" do
    test "prefers explicit base path from assigns" do
      assert LiveOrganization.base_path(%{organization_base_path: "/app/demo"}) == "/app/demo"
    end

    test "derives base path from slug when explicit path missing" do
      assert LiveOrganization.base_path(%{organization_slug: "demo"}) == "/app/demo"
    end

    test "handles LiveView socket structs" do
      socket = %Phoenix.LiveView.Socket{assigns: %{organization_base_path: "/app/socket"}}

      assert LiveOrganization.base_path(socket) == "/app/socket"
    end

    test "falls back to empty string when no organization info is present" do
      assert LiveOrganization.base_path(%{}) == ""
      assert LiveOrganization.base_path(nil) == ""
    end
  end

  describe "scoped_path/3" do
    test "builds paths under the provided base path" do
      assert LiveOrganization.scoped_path("/app/demo", ["manage", "orders"]) ==
               "/app/demo/manage/orders"
    end

    test "handles empty base path by returning absolute segment path" do
      assert LiveOrganization.scoped_path("", ["manage", "orders"]) == "/manage/orders"
    end

    test "returns base path when no segments provided" do
      assert LiveOrganization.scoped_path("/app/demo", []) == "/app/demo"
    end

    test "appends query params from maps and keyword lists" do
      assert LiveOrganization.scoped_path("/app/demo", ["manage", "orders"], view: "calendar") ==
               "/app/demo/manage/orders?view=calendar"

      assert LiveOrganization.scoped_path("/app/demo", ["manage", "orders"], %{page: 2}) ==
               "/app/demo/manage/orders?page=2"
    end

    test "appends query strings directly" do
      assert LiveOrganization.scoped_path("/app/demo", ["manage"], "foo=bar") ==
               "/app/demo/manage?foo=bar"
    end

    test "ignores blank query inputs" do
      assert LiveOrganization.scoped_path("/app/demo", ["manage"], []) == "/app/demo/manage"
      assert LiveOrganization.scoped_path("/app/demo", ["manage"], %{}) == "/app/demo/manage"
      assert LiveOrganization.scoped_path("/app/demo", ["manage"], "") == "/app/demo/manage"
    end
  end
end
