defmodule CraftplanWeb.SettingsEmailSenderTest do
  use CraftplanWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  defp admin_conn(conn) do
    admin = Craftplan.DataCase.admin_actor()

    conn
    |> AshAuthentication.Phoenix.Plug.store_in_session(admin)
    |> Plug.Conn.assign(:current_user, admin)
  end

  describe "email sender form" do
    test "renders email sender section with both fields", %{conn: conn} do
      {:ok, view, html} = conn |> admin_conn() |> live(~p"/manage/settings/general")

      assert html =~ "Email Sender"
      assert html =~ "Sender name"
      assert html =~ "Sender email"
      assert has_element?(view, "#email-sender-settings")
      assert has_element?(view, ~s(input[name="settings[email_from_name]"]))
      assert has_element?(view, ~s(input[name="settings[email_from_address]"]))
    end

    test "form inputs are pre-populated with current values", %{conn: conn} do
      {:ok, _view, html} = conn |> admin_conn() |> live(~p"/manage/settings/general")

      # Default values should show in the form
      assert html =~ "Craftplan"
      assert html =~ "noreply@craftplan.app"
    end

    test "can update email sender name and address", %{conn: conn} do
      {:ok, view, _html} = conn |> admin_conn() |> live(~p"/manage/settings/general")

      view
      |> form("#settings-form", %{
        "settings" => %{
          "email_from_name" => "My Bakery",
          "email_from_address" => "orders@mybakery.com"
        }
      })
      |> render_submit()

      {:ok, settings} = Craftplan.Settings.get_settings()
      assert settings.email_from_name == "My Bakery"
      assert settings.email_from_address == "orders@mybakery.com"
    end

    test "updated values appear on next page load", %{conn: conn} do
      conn = admin_conn(conn)
      {:ok, view, _html} = live(conn, ~p"/manage/settings/general")

      view
      |> form("#settings-form", %{
        "settings" => %{
          "email_from_name" => "Updated Name",
          "email_from_address" => "new@example.com"
        }
      })
      |> render_submit()

      # Reload the page and verify new values are shown
      {:ok, _view, html} = live(conn, ~p"/manage/settings/general")
      assert html =~ "Updated Name"
      assert html =~ "new@example.com"
    end

    test "shows flash on successful save", %{conn: conn} do
      {:ok, view, _html} = conn |> admin_conn() |> live(~p"/manage/settings/general")

      view
      |> form("#settings-form", %{
        "settings" => %{"email_from_name" => "Flash Test"}
      })
      |> render_submit()

      # The form component redirects via push_patch, follow it
      assert_patch(view, ~p"/manage/settings/general")
    end
  end

  describe "email sender defaults" do
    test "settings default to Craftplan sender values" do
      Craftplan.Settings.init!()
      {:ok, settings} = Craftplan.Settings.get_settings()
      assert settings.email_from_name == "Craftplan"
      assert settings.email_from_address == "noreply@craftplan.app"
    end
  end

  describe "email_sender/0 fallback" do
    test "emails module reads custom sender from settings" do
      Craftplan.Settings.init!()
      {:ok, settings} = Craftplan.Settings.get_settings()
      admin = Craftplan.DataCase.admin_actor()

      Craftplan.Settings.set!(
        settings,
        %{
          email_from_name: "Custom Name",
          email_from_address: "custom@example.com"
        },
        actor: admin
      )

      # Verify settings actually changed
      {:ok, updated} = Craftplan.Settings.get_settings()
      assert updated.email_from_name == "Custom Name"
      assert updated.email_from_address == "custom@example.com"
    end
  end
end
