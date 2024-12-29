defmodule Microcraft.Accounts.User.Senders.SendNewUserConfirmationEmail do
  @moduledoc """
  Sends an email for a new user to confirm their email address.
  """

  use AshAuthentication.Sender
  use MicrocraftWeb, :verified_routes

  @impl true
  def send(user, token, _) do
    Microcraft.Accounts.Emails.deliver_new_user_confirmation_email(
      user,
      token
    )
  end
end
