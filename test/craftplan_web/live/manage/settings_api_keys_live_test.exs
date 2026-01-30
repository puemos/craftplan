defmodule CraftplanWeb.SettingsApiKeysLiveTest do
  use CraftplanWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Craftplan.Accounts

  defp admin_conn(conn) do
    admin = Craftplan.DataCase.admin_actor()

    conn =
      conn
      |> AshAuthentication.Phoenix.Plug.store_in_session(admin)
      |> Plug.Conn.assign(:current_user, admin)

    {conn, admin}
  end

  describe "index" do
    test "admin sees API Keys tab", %{conn: conn} do
      {conn, _admin} = admin_conn(conn)

      {:ok, view, _html} = live(conn, ~p"/manage/settings/api_keys")

      assert has_element?(view, "header", "API Keys")
    end

    test "renders empty state when no keys exist", %{conn: conn} do
      {conn, _admin} = admin_conn(conn)

      {:ok, view, _html} = live(conn, ~p"/manage/settings/api_keys")

      assert has_element?(view, "div", "No API keys yet")
    end

    test "lists existing keys with name and prefix", %{conn: conn} do
      {conn, admin} = admin_conn(conn)

      {:ok, api_key} =
        Accounts.create_api_key(
          %{name: "My Test Key", scopes: %{"products" => ["read"]}},
          actor: admin
        )

      {:ok, view, _html} = live(conn, ~p"/manage/settings/api_keys")

      assert has_element?(view, "#api-keys", "My Test Key")
      assert has_element?(view, "#api-keys", "#{api_key.prefix}...")
    end
  end

  describe "create" do
    test "opens create modal", %{conn: conn} do
      {conn, _admin} = admin_conn(conn)

      {:ok, view, _html} = live(conn, ~p"/manage/settings/api_keys")

      view |> element("button", "Create API Key") |> render_click()

      assert has_element?(view, "#create-api-key-modal")
      assert has_element?(view, "#api-key-form")
    end

    test "creates key and shows raw key banner", %{conn: conn} do
      {conn, _admin} = admin_conn(conn)

      {:ok, view, _html} = live(conn, ~p"/manage/settings/api_keys")

      view |> element("button", "Create API Key") |> render_click()

      view
      |> form("#api-key-form", %{"api_key" => %{"name" => "New Key"}})
      |> render_submit(%{
        "api_key" => %{"name" => "New Key"},
        "scopes" => %{"products" => %{"read" => "true"}}
      })

      # Should show raw key banner
      assert has_element?(view, "#raw-key-display")
      html = render(view)
      assert html =~ "cpk_"
      assert html =~ "copy it now"
    end

    test "new key appears in table", %{conn: conn} do
      {conn, _admin} = admin_conn(conn)

      {:ok, view, _html} = live(conn, ~p"/manage/settings/api_keys")

      view |> element("button", "Create API Key") |> render_click()

      view
      |> form("#api-key-form", %{"api_key" => %{"name" => "Listed Key"}})
      |> render_submit(%{
        "api_key" => %{"name" => "Listed Key"},
        "scopes" => %{"products" => %{"read" => "true"}}
      })

      assert has_element?(view, "#api-keys", "Listed Key")
    end
  end

  describe "revoke" do
    test "revoke button marks key as revoked", %{conn: conn} do
      {conn, admin} = admin_conn(conn)

      {:ok, _api_key} =
        Accounts.create_api_key(
          %{name: "To Revoke", scopes: %{"products" => ["read"]}},
          actor: admin
        )

      {:ok, view, _html} = live(conn, ~p"/manage/settings/api_keys")

      assert has_element?(view, "span", "Active")

      view |> element("button", "Revoke") |> render_click()

      assert has_element?(view, "span", "Revoked")
    end
  end
end
