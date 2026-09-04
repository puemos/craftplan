defmodule CraftplanWeb.AuthConfirmationControllerTest do
  use CraftplanWeb.ConnCase, async: true

  alias Craftplan.Accounts
  alias Craftplan.Test.AuthHelpers

  for role <- [:staff, :admin] do
    @role role

    test "invited #{role} users can confirm their accounts from the emailed link", %{conn: conn} do
      inviting_admin = AuthHelpers.register_user!(role: :admin)
      assert_receive {:email, _inviting_admin_confirmation}

      email_address = "invited-#{@role}+#{System.unique_integer([:positive])}@test.com"

      assert {:ok, invited_user} =
               Accounts.invite_member(
                 %{email: email_address, role: @role},
                 actor: inviting_admin
               )

      assert is_nil(invited_user.confirmed_at)
      assert_receive {:email, confirmation_email}

      assert [confirmation_url] =
               Regex.run(~r/href="([^"]+)"/, confirmation_email.html_body, capture: :all_but_first)

      uri = URI.parse(confirmation_url)
      confirmation_path = uri.path <> "?" <> uri.query

      conn = get(conn, confirmation_path)
      document = conn |> html_response(200) |> LazyHTML.from_document()
      confirmation_form = LazyHTML.query(document, "form[action='/auth/user/confirm_new_user']")

      assert ["post"] = LazyHTML.attribute(confirmation_form, "method")

      assert [csrf_token] =
               confirmation_form
               |> LazyHTML.query("input[name='_csrf_token']")
               |> LazyHTML.attribute("value")

      assert [confirmation_token] =
               confirmation_form
               |> LazyHTML.query("input[name='user[confirm]']")
               |> LazyHTML.attribute("value")

      conn =
        post(conn, "/auth/user/confirm_new_user", %{
          "_csrf_token" => csrf_token,
          "user" => %{"confirm" => confirmation_token}
        })

      assert redirected_to(conn) == ~p"/manage/overview"

      assert {:ok, confirmed_user} = Accounts.get_user_by_email(email_address, authorize?: false)
      assert %DateTime{} = confirmed_user.confirmed_at
      assert confirmed_user.role == @role
    end
  end
end
