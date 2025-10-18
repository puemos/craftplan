defmodule Craftplan.Test.AuthHelpers do
  @moduledoc """
  Test-only helpers for registering users with tokens and signing in connections.
  Compatible with AshAuthentication when `require_token_presence_for_authentication?` is true.
  """

  alias AshAuthentication.Strategy.Password
  alias Craftplan.Accounts.User

  @default_password "Passw0rd!!"

  @doc """
  Registers a new user for the given role and returns the created user.
  The returned struct includes a token in `__metadata__.token`.
  """
  def register_user!(opts \\ []) do
    role = Keyword.get(opts, :role, :customer)
    email = Keyword.get(opts, :email, unique_email(role))

    User
    |> Ash.Changeset.for_create(:register_with_password, %{
      email: email,
      role: role,
      password: @default_password,
      password_confirmation: @default_password
    })
    |> Ash.create!(
      context: %{
        strategy: Password,
        private: %{ash_authentication?: true}
      }
    )
  end

  @doc """
  Ensures the provided user has a token in metadata.
  For users created via `register_user!/1`, this is already true.
  """
  def ensure_token!(%{__metadata__: %{token: token}} = user) when is_binary(token), do: user
  def ensure_token!(user), do: user

  @doc """
  Signs in the given user on the provided connection by storing the token in session
  and assigning `:current_user`. Also sets a default timezone test cookie.
  """
  def sign_in(conn, user) do
    conn
    |> Plug.Test.put_req_cookie("timezone", "Etc/UTC")
    |> AshAuthentication.Phoenix.Plug.store_in_session(user)
    |> Plug.Conn.assign(:current_user, user)
  end

  @doc """
  Convenience helper to register a user for a given role and sign them in.
  Returns `{conn, user}`.
  """
  def sign_in_as(conn, role) do
    user = register_user!(role: role) |> ensure_token!()
    {sign_in(conn, user), user}
  end

  defp unique_email(role), do: "#{role}+#{System.unique_integer([:positive])}@local"
end

