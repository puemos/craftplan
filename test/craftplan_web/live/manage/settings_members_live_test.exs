defmodule CraftplanWeb.SettingsMembersLiveTest do
  use CraftplanWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Craftplan.Accounts.User

  defp create_staff_member!(email) do
    User
    |> Ash.Changeset.for_create(:register_with_password, %{
      email: email,
      role: :staff,
      password: "TestPassword123!",
      password_confirmation: "TestPassword123!"
    })
    |> Ash.create!(
      context: %{
        strategy: AshAuthentication.Strategy.Password,
        private: %{ash_authentication?: true}
      }
    )
  end

  describe "index" do
    @tag role: :admin
    test "admin sees Members tab", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/manage/settings/members")

      assert has_element?(view, "header", "Members")
    end

    @tag role: :admin
    test "lists existing members with email and role", %{conn: conn} do
      email = "staff+#{System.unique_integer()}@test.com"
      create_staff_member!(email)

      {:ok, view, _html} = live(conn, ~p"/manage/settings/members")

      assert render(view) =~ email
    end

    @tag role: :admin
    test "shows edit and remove buttons for other members", %{conn: conn, user: admin} do
      create_staff_member!("other+#{System.unique_integer()}@test.com")

      {:ok, view, _html} = live(conn, ~p"/manage/settings/members")

      html = render(view)

      assert html =~ "Edit"
      assert html =~ "Remove"
      assert html =~ to_string(admin.email)
    end
  end

  describe "invite" do
    @tag role: :admin
    test "opens invite modal", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/manage/settings/members")

      view |> element("button", "Invite Member") |> render_click()

      assert has_element?(view, "#invite-member-modal")
      assert has_element?(view, "#invite-member-form")
    end

    @tag role: :admin
    test "invites new staff member and shows in table", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/manage/settings/members")

      view |> element("button", "Invite Member") |> render_click()

      email = "invited+#{System.unique_integer()}@test.com"

      view
      |> form("#invite-member-form", %{"invite" => %{"email" => email}})
      |> render_change(%{"invite" => %{"email" => email, "role" => "staff"}})

      view
      |> form("#invite-member-form", %{"invite" => %{"email" => email, "role" => "staff"}})
      |> render_submit()

      assert render(view) =~ email
    end
  end

  describe "update role" do
    @tag role: :admin
    test "opens edit role modal and updates role", %{conn: conn} do
      create_staff_member!("editrole+#{System.unique_integer()}@test.com")

      {:ok, view, _html} = live(conn, ~p"/manage/settings/members")

      view |> element("button", "Edit") |> render_click()

      assert has_element?(view, "#edit-role-modal")

      view
      |> form("#edit-role-form", %{"role_edit" => %{"role" => "admin"}})
      |> render_change(%{"role_edit" => %{"role" => "admin"}})

      view
      |> form("#edit-role-form", %{"role_edit" => %{"role" => "admin"}})
      |> render_submit()

      # Modal closes after update — verify by checking it's gone
      refute has_element?(view, "#edit-role-modal")
    end
  end

  describe "remove" do
    @tag role: :admin
    test "removes a member from the list", %{conn: conn} do
      email = "remove+#{System.unique_integer()}@test.com"
      create_staff_member!(email)

      {:ok, view, _html} = live(conn, ~p"/manage/settings/members")

      assert render(view) =~ email

      view |> element("button", "Remove") |> render_click()

      refute render(view) =~ email
    end
  end
end
