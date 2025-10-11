defmodule CraftdayWeb.CartSessionPlugTest do
  use CraftdayWeb.ConnCase, async: true

  test "invalid cart id in session does not crash and redirects to sign-in" do
    bogus = Ecto.UUID.generate()

    conn =
      build_conn()
      |> init_test_session(%{cart_id: bogus})
      |> get(~p"/manage/settings")

    assert redirected_to(conn, 302) =~ "/sign-in"
  end
end
