defmodule Craftplan.DataCase do
  @moduledoc """
  This module defines the setup for tests requiring
  access to the application's data layer.

  You may define functions here to be used as helpers in
  your tests.

  Finally, if the test case interacts with the database,
  we enable the SQL sandbox, so changes done to the database
  are reverted at the end of every test. If you are using
  PostgreSQL, you can even run database tests asynchronously
  by setting `use Craftplan.DataCase, async: true`, although
  this option is not recommended for other databases.
  """

  use ExUnit.CaseTemplate

  alias AshAuthentication.Strategy.Password
  alias Craftplan.Accounts.User
  alias Ecto.Adapters.SQL.Sandbox

  using do
    quote do
      import Craftplan.DataCase
      import Ecto
      import Ecto.Changeset
      import Ecto.Query

      alias Craftplan.Repo
    end
  end

  setup tags do
    Craftplan.DataCase.setup_sandbox(tags)
    :ok
  end

  @doc """
  Sets up the sandbox based on the test tags.
  """
  def setup_sandbox(tags) do
    pid = Sandbox.start_owner!(Craftplan.Repo, shared: not tags[:async])
    on_exit(fn -> Sandbox.stop_owner(pid) end)
  end

  @doc """
  A helper that transforms changeset errors into a map of messages.

      assert {:error, changeset} = Accounts.create_user(%{password: "short"})
      assert "password is too short" in errors_on(changeset).password
      assert %{password: ["password is too short"]} = errors_on(changeset)

  """
  def errors_on(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {message, opts} ->
      Regex.replace(~r"%{(\w+)}", message, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
  end

  @doc """
  Create a staff user for use as an actor in tests that require authorization.
  """
  def staff_actor do
    email = "staff+#{System.unique_integer([:positive])}@local"

    User
    |> Ash.Changeset.for_create(:register_with_password, %{
      email: email,
      password: "Passw0rd!!",
      password_confirmation: "Passw0rd!!",
      role: :staff
    })
    |> Ash.create!(
      context: %{
        strategy: Password,
        private: %{ash_authentication?: true}
      }
    )
  end

  @doc """
  Create or fetch an admin user for tests requiring elevated privileges.
  """
  def admin_actor do
    email = "admin+#{System.unique_integer([:positive])}@local"

    User
    |> Ash.Changeset.for_create(:register_with_password, %{
      email: email,
      password: "Passw0rd!!",
      password_confirmation: "Passw0rd!!",
      role: :admin
    })
    |> Ash.create!(
      context: %{
        strategy: Password,
        private: %{ash_authentication?: true}
      }
    )
  end
end
