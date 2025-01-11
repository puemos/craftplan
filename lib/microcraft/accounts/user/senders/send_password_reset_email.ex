defmodule CraftScale.Accounts.User.Senders.SendPasswordResetEmail do
  @moduledoc """
  Sends a password reset email
  """

  use AshAuthentication.Sender
  use CraftScaleWeb, :verified_routes

  @impl true
  def send(user, token, _) do
    CraftScale.Accounts.Emails.deliver_reset_password_instructions(
      user,
      url(~p"/password-reset/#{token}")
    )
  end
end
