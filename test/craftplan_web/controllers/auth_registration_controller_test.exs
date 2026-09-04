defmodule CraftplanWeb.AuthRegistrationControllerTest do
  use CraftplanWeb.ConnCase, async: true

  test "public registration cannot assign an administrator role", %{conn: conn} do
    email = "registration-role+#{System.unique_integer([:positive])}@test.com"

    conn =
      post(conn, ~p"/auth/user/password/register", %{
        "user" => %{
          "email" => email,
          "password" => "Password12345!",
          "password_confirmation" => "Password12345!",
          "role" => "admin"
        }
      })

    assert redirected_to(conn) == ~p"/manage/overview"
    assert {:ok, user} = Craftplan.Accounts.get_user_by_email(email, authorize?: false)
    assert user.role == :customer
  end
end
