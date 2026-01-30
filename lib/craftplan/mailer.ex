defmodule Craftplan.Mailer do
  @moduledoc false
  use Swoosh.Mailer, otp_app: :craftplan

  @doc """
  Applies email provider configuration from a Settings record to the mailer.

  Dispatches on `settings.email_provider` to configure the appropriate
  Swoosh adapter. Called both on application boot and when a user saves
  settings in the UI.
  """
  def apply_settings(settings) do
    case provider_config(settings) do
      nil -> :ok
      config -> apply_config(config)
    end
  end

  defp provider_config(%{email_provider: :sendgrid} = s) do
    if present?(s.email_api_key),
      do: [adapter: Swoosh.Adapters.SendGrid, api_key: s.email_api_key]
  end

  defp provider_config(%{email_provider: :postmark} = s) do
    if present?(s.email_api_key),
      do: [adapter: Swoosh.Adapters.Postmark, api_key: s.email_api_key]
  end

  defp provider_config(%{email_provider: :brevo} = s) do
    if present?(s.email_api_key),
      do: [adapter: Swoosh.Adapters.Brevo, api_key: s.email_api_key]
  end

  defp provider_config(%{email_provider: :mailgun} = s) do
    if present?(s.email_api_key),
      do: [adapter: Swoosh.Adapters.Mailgun, api_key: s.email_api_key, domain: s.email_api_domain]
  end

  defp provider_config(%{email_provider: :amazon_ses} = s) do
    if present?(s.email_api_key) and present?(s.email_api_secret) do
      [
        adapter: Swoosh.Adapters.AmazonSES,
        access_key: s.email_api_key,
        secret: s.email_api_secret,
        region: s.email_api_region || "us-east-1"
      ]
    end
  end

  defp provider_config(%{email_provider: :smtp} = s) do
    if present?(s.smtp_host) do
      has_credentials? = present?(s.smtp_username) and present?(s.smtp_password)

      [
        adapter: Swoosh.Adapters.SMTP,
        relay: s.smtp_host,
        port: s.smtp_port || 587,
        username: s.smtp_username || "",
        password: s.smtp_password || "",
        tls: s.smtp_tls || :if_available,
        auth: if(has_credentials?, do: :always, else: :never)
      ]
    end
  end

  defp provider_config(_), do: nil

  defp apply_config(config) do
    Application.put_env(:craftplan, __MODULE__, config)
    Application.put_env(:swoosh, :api_client, Swoosh.ApiClient.Finch)
    Application.put_env(:swoosh, :finch_name, Craftplan.Finch)
    :ok
  end

  defp present?(value), do: value not in [nil, ""]
end
