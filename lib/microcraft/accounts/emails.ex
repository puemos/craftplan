defmodule Microcraft.Accounts.Emails do
  @moduledoc """
  Delivers emails.
  """

  import Swoosh.Email

  def deliver_reset_password_instructions(user, url) do
    if !url do
      raise "Cannot deliver reset instructions without a url"
    end

    deliver(user.email, "Reset Your Password", """
    <html>
      <p>
        Hi #{user.email},
      </p>

      <p>
        <a href="#{url}">Click here</a> to reset your password.
      </p>

      <p>
        If you didn't request this change, please ignore this.
      </p>
    <html>
    """)
  end

  def deliver_new_user_confirmation_email(user, url) do
    if !url do
      raise "Cannot deliver confirmation instructions without a url"
    end

    deliver(user.email, "Confirm Your Email", """
    <html>
      <p>
        Hi #{user.email},
      </p>

      <p>
        <a href="#{url}">Click here</a> to confirm your email.
      </p>
    <html>
    """)
  end

  # For simplicity, this module simply logs messages to the terminal.
  # You should replace it by a proper email or notification tool, such as:
  #
  #   * Swoosh - https://hexdocs.pm/swoosh
  #   * Bamboo - https://hexdocs.pm/bamboo
  #
  defp deliver(to, subject, body) do
    new()
    # TODO: Replace with your email
    |> from({"Zach", "zach@ash-hq.org"})
    |> to(to_string(to))
    |> subject(subject)
    |> put_provider_option(:track_links, "None")
    |> html_body(body)
    |> Microcraft.Mailer.deliver!()
  end
end
