defmodule Craftplan.Accounts.User.Senders.SendNewUserConfirmationEmail do
  @moduledoc """
  Sends email confirmation or invited-account setup instructions for a new user.
  """

  use AshAuthentication.Sender
  use CraftplanWeb, :verified_routes

  alias AshAuthentication.Info
  alias AshAuthentication.Strategy.Password
  alias Craftplan.Accounts.Emails
  alias Craftplan.Accounts.User

  @impl true
  def send(user, confirmation_token, opts) do
    send_for_action(user, confirmation_token, Keyword.get(opts, :changeset))
  end

  defp send_for_action(user, _confirmation_token, %Ash.Changeset{action: %{name: :invite}}) do
    # Invited users start with an unknowable generated password. Setting a password through the
    # reset action also confirms the email, so they cannot be stranded after their first sign-out.
    password_strategy = Info.strategy!(User, :password)
    {:ok, reset_token} = Password.reset_token_for(password_strategy, user)

    Emails.deliver_invitation_email(
      user,
      url(~p"/password-reset/#{reset_token}")
    )
  end

  defp send_for_action(user, confirmation_token, _changeset) do
    Emails.deliver_new_user_confirmation_email(
      user,
      url(~p"/auth/user/confirm_new_user?#{[confirm: confirmation_token]}")
    )
  end
end
