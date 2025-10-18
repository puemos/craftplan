defmodule CraftplanWeb.ConnCase do
  @moduledoc """
  This module defines the test case to be used by
  tests that require setting up a connection.

  Such tests rely on `Phoenix.ConnTest` and also
  import other functionality to make it easier
  to build common data structures and query the data layer.

  Finally, if the test case interacts with the database,
  we enable the SQL sandbox, so changes done to the database
  are reverted at the end of every test. If you are using
  PostgreSQL, you can even run database tests asynchronously
  by setting `use CraftplanWeb.ConnCase, async: true`, although
  this option is not recommended for other databases.
  """

  use ExUnit.CaseTemplate

  using do
    quote do
      use CraftplanWeb, :verified_routes

      import CraftplanWeb.ConnCase
      import Phoenix.ConnTest
      import Plug.Conn
      # The default endpoint for testing
      @endpoint CraftplanWeb.Endpoint

      # Import conveniences for testing with connections
    end
  end

  setup tags do
    Craftplan.DataCase.setup_sandbox(tags)
    conn = Phoenix.ConnTest.build_conn()
    metadata = Phoenix.Ecto.SQL.Sandbox.metadata_for(Craftplan.Repo, self())

    conn =
      conn
      |> Plug.Test.init_test_session(%{})
      |> Plug.Conn.put_session(:phoenix_ecto_sandbox, metadata)
      |> Plug.Test.put_req_cookie("timezone", "Etc/UTC")

    case tags[:role] do
      nil -> {:ok, conn: conn}
      role ->
        user = Craftplan.Test.AuthHelpers.register_user!(role: role) |> Craftplan.Test.AuthHelpers.ensure_token!()
        conn = Craftplan.Test.AuthHelpers.sign_in(conn, user)
        {:ok, conn: conn, user: user}
    end
  end
end
