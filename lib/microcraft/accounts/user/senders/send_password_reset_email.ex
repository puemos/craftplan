defmodule Microcraft.Accounts.User.Senders.SendPasswordResetEmail do
  @moduledoc """
  Sends a password reset email
  """

  use AshAuthentication.Sender
  use MicrocraftWeb, :verified_routes

  @impl true
  def send(user, token, _) do
    Microcraft.Accounts.Emails.deliver_reset_password_instructions(
      user,
      token
    )
  end
end
