defmodule CraftdayWeb.ManageSettingsLiveTest do
  use CraftdayWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  describe "admin access" do
    test "renders settings index for admin", %{conn: conn} do
      admin = Craftday.DataCase.admin_actor()

      conn =
        conn
        |> AshAuthentication.Phoenix.Plug.store_in_session(admin)
        |> Plug.Conn.assign(:current_user, admin)

      {:ok, view, _html} = live(conn, ~p"/manage/settings")

      assert has_element?(view, "[role=tablist]")
      assert has_element?(view, "#settings-form")
    end

    test "renders general tab for admin", %{conn: conn} do
      admin = Craftday.DataCase.admin_actor()

      conn =
        conn
        |> AshAuthentication.Phoenix.Plug.store_in_session(admin)
        |> Plug.Conn.assign(:current_user, admin)

      {:ok, view, _html} = live(conn, ~p"/manage/settings/general")

      assert has_element?(view, "[role=tablist]")
      assert has_element?(view, "#settings-form")
    end

    test "renders allergens tab for admin", %{conn: conn} do
      admin = Craftday.DataCase.admin_actor()

      conn =
        conn
        |> AshAuthentication.Phoenix.Plug.store_in_session(admin)
        |> Plug.Conn.assign(:current_user, admin)

      {:ok, view, _html} = live(conn, ~p"/manage/settings/allergens")

      assert has_element?(view, "[role=tablist]")
      assert has_element?(view, "#allergens")
    end

    test "renders nutritional facts tab for admin", %{conn: conn} do
      admin = Craftday.DataCase.admin_actor()

      conn =
        conn
        |> AshAuthentication.Phoenix.Plug.store_in_session(admin)
        |> Plug.Conn.assign(:current_user, admin)

      {:ok, view, _html} = live(conn, ~p"/manage/settings/nutritional_facts")

      assert has_element?(view, "[role=tablist]")
      assert has_element?(view, "#nutritional-facts")
    end
  end

  describe "unauthenticated access" do
    test "redirects settings index to sign-in", %{conn: conn} do
      assert {:error, {:redirect, %{to: "/sign-in"}}} = live(conn, ~p"/manage/settings")
    end
  end
end
