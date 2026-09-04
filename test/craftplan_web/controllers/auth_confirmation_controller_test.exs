defmodule CraftplanWeb.AuthConfirmationControllerTest do
  use CraftplanWeb.ConnCase, async: true

  alias Craftplan.Accounts
  alias Craftplan.Test.AuthHelpers

  test "users who chose a password can confirm their email from the emailed link", %{conn: conn} do
    registered_user = AuthHelpers.register_user!()
    assert_receive {:email, confirmation_email}

    assert [confirmation_url] =
             Regex.run(~r/href="([^"]+)"/, confirmation_email.html_body, capture: :all_but_first)

    uri = URI.parse(confirmation_url)
    confirmation_path = uri.path <> "?" <> uri.query

    conn = get(conn, confirmation_path)
    document = conn |> html_response(200) |> LazyHTML.from_document()
    confirmation_form = LazyHTML.query(document, "form[action='/auth/user/confirm_new_user']")

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

    assert {:ok, confirmed_user} =
             Accounts.get_user_by_email(registered_user.email, authorize?: false)

    assert %DateTime{} = confirmed_user.confirmed_at
  end

  for role <- [:staff, :admin] do
    @role role

    test "invited #{role} users set a password and can sign back in", %{conn: conn} do
      inviting_admin = AuthHelpers.register_user!(role: :admin)

      assert_receive {:email, inviting_admin_confirmation}
      assert inviting_admin_confirmation.html_body =~ "/auth/user/confirm_new_user?confirm="

      email_address = "invited-#{@role}+#{System.unique_integer([:positive])}@test.com"
      password = "InvitedPassword123!"

      assert {:ok, invited_user} =
               Accounts.invite_member(
                 %{email: email_address, role: @role},
                 actor: inviting_admin
               )

      assert is_nil(invited_user.confirmed_at)
      assert_receive {:email, invitation_email}
      assert invitation_email.subject == "Set up your Craftplan account"

      assert [invitation_url] =
               Regex.run(~r/href="([^"]+)"/, invitation_email.html_body, capture: :all_but_first)

      assert invitation_email.html_body =~ "expires in 3 days"

      invitation_path = URI.parse(invitation_url).path
      assert String.starts_with?(invitation_path, "/password-reset/")

      conn = get(conn, invitation_path)
      document = conn |> html_response(200) |> LazyHTML.from_document()
      reset_form = LazyHTML.query(document, "form[action='/auth/user/password/reset']")

      assert ["post"] = LazyHTML.attribute(reset_form, "method")
      image_sources = document |> LazyHTML.query("img") |> LazyHTML.attribute("src")
      assert image_sources != []
      assert Enum.all?(image_sources, &String.starts_with?(&1, "/"))

      refute document
             |> LazyHTML.query("link[rel='stylesheet']")
             |> LazyHTML.attribute("href")
             |> Enum.any?(&String.starts_with?(&1, "http"))

      assert [csrf_token] =
               reset_form
               |> LazyHTML.query("input[name='_csrf_token']")
               |> LazyHTML.attribute("value")

      assert [reset_token] =
               reset_form
               |> LazyHTML.query("input[name='user[reset_token]']")
               |> LazyHTML.attribute("value")

      conn =
        post(conn, "/auth/user/password/reset", %{
          "_csrf_token" => csrf_token,
          "user" => %{
            "reset_token" => reset_token,
            "password" => password,
            "password_confirmation" => password
          }
        })

      assert redirected_to(conn) == ~p"/manage/overview"

      assert {:ok, confirmed_user} = Accounts.get_user_by_email(email_address, authorize?: false)
      assert %DateTime{} = confirmed_user.confirmed_at
      assert confirmed_user.role == @role

      sign_in_conn = get(build_conn(), ~p"/sign-in")
      sign_in_document = sign_in_conn |> html_response(200) |> LazyHTML.from_document()

      sign_in_form =
        LazyHTML.query(sign_in_document, "form[action='/auth/user/password/sign_in']")

      assert [sign_in_csrf_token] =
               sign_in_form
               |> LazyHTML.query("input[name='_csrf_token']")
               |> LazyHTML.attribute("value")

      sign_in_conn =
        post(sign_in_conn, "/auth/user/password/sign_in", %{
          "_csrf_token" => sign_in_csrf_token,
          "user" => %{"email" => email_address, "password" => password}
        })

      assert redirected_to(sign_in_conn) == ~p"/manage/overview"
      assert sign_in_conn |> recycle() |> get(~p"/manage/overview") |> html_response(200)
    end
  end

  test "legacy confirmation links for invited users continue into password setup", %{conn: conn} do
    inviting_admin = AuthHelpers.register_user!(role: :admin)
    assert_receive {:email, _inviting_admin_confirmation}

    email_address = "legacy-invite+#{System.unique_integer([:positive])}@test.com"
    password = "LegacyInvitePassword123!"

    assert {:ok, invited_user} =
             Accounts.invite_member(
               %{email: email_address, role: :staff},
               actor: inviting_admin
             )

    assert_receive {:email, _invitation_email}
    confirmation_token = invited_user.__metadata__.confirmation_token

    conn = get(conn, ~p"/auth/user/confirm_new_user?#{[confirm: confirmation_token]}")
    document = conn |> html_response(200) |> LazyHTML.from_document()
    confirmation_form = LazyHTML.query(document, "form[action='/auth/user/confirm_new_user']")

    [csrf_token] =
      confirmation_form
      |> LazyHTML.query("input[name='_csrf_token']")
      |> LazyHTML.attribute("value")

    [confirmation_token] =
      confirmation_form
      |> LazyHTML.query("input[name='user[confirm]']")
      |> LazyHTML.attribute("value")

    conn =
      post(conn, "/auth/user/confirm_new_user", %{
        "_csrf_token" => csrf_token,
        "user" => %{"confirm" => confirmation_token}
      })

    password_setup_path = redirected_to(conn)
    assert String.starts_with?(password_setup_path, "/password-reset/")

    conn = get(recycle(conn), password_setup_path)
    document = conn |> html_response(200) |> LazyHTML.from_document()
    reset_form = LazyHTML.query(document, "form[action='/auth/user/password/reset']")

    [csrf_token] =
      reset_form
      |> LazyHTML.query("input[name='_csrf_token']")
      |> LazyHTML.attribute("value")

    [reset_token] =
      reset_form
      |> LazyHTML.query("input[name='user[reset_token]']")
      |> LazyHTML.attribute("value")

    conn =
      post(conn, "/auth/user/password/reset", %{
        "_csrf_token" => csrf_token,
        "user" => %{
          "reset_token" => reset_token,
          "password" => password,
          "password_confirmation" => password
        }
      })

    assert redirected_to(conn) == ~p"/manage/overview"

    sign_in_conn = get(build_conn(), ~p"/sign-in")
    sign_in_document = sign_in_conn |> html_response(200) |> LazyHTML.from_document()
    sign_in_form = LazyHTML.query(sign_in_document, "form[action='/auth/user/password/sign_in']")

    [sign_in_csrf_token] =
      sign_in_form
      |> LazyHTML.query("input[name='_csrf_token']")
      |> LazyHTML.attribute("value")

    sign_in_conn =
      post(sign_in_conn, "/auth/user/password/sign_in", %{
        "_csrf_token" => sign_in_csrf_token,
        "user" => %{"email" => email_address, "password" => password}
      })

    assert redirected_to(sign_in_conn) == ~p"/manage/overview"
    assert sign_in_conn |> recycle() |> get(~p"/manage/overview") |> html_response(200)
  end
end
