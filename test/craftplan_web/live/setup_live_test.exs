defmodule CraftplanWeb.SetupLiveTest do
  use CraftplanWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  test "creates the initial user as an administrator", %{conn: conn} do
    email = "initial-admin+#{System.unique_integer([:positive])}@test.com"

    {:ok, view, _html} = live(conn, ~p"/setup")

    view
    |> form("#setup-form", %{
      "user" => %{
        "email" => email,
        "password" => "Password12345!",
        "password_confirmation" => "Password12345!"
      }
    })
    |> render_submit()

    assert_redirect(view, ~p"/sign-in")
    assert {:ok, user} = Craftplan.Accounts.get_user_by_email(email, authorize?: false)
    assert user.role == :admin
  end
end
