defmodule Craftplan.MailerTest do
  use ExUnit.Case, async: true

  alias Craftplan.Mailer

  setup do
    # Restore original mailer config after each test
    original = Application.get_env(:craftplan, Mailer)
    on_exit(fn -> Application.put_env(:craftplan, Mailer, original) end)
    :ok
  end

  defp settings(attrs) do
    Map.merge(
      %{
        email_provider: :smtp,
        email_api_key: nil,
        email_api_secret: nil,
        email_api_domain: nil,
        email_api_region: "us-east-1",
        smtp_host: nil,
        smtp_port: 587,
        smtp_username: nil,
        smtp_password: nil,
        smtp_tls: :if_available
      },
      attrs
    )
  end

  describe "apply_settings/1 SMTP" do
    test "configures SMTP adapter when host is present" do
      s = settings(%{smtp_host: "smtp.example.com", smtp_username: "user", smtp_password: "pass"})
      assert :ok = Mailer.apply_settings(s)

      config = Application.get_env(:craftplan, Mailer)
      assert config[:adapter] == Swoosh.Adapters.SMTP
      assert config[:relay] == "smtp.example.com"
      assert config[:auth] == :always
    end

    test "skips configuration when host is blank" do
      original = Application.get_env(:craftplan, Mailer)
      s = settings(%{smtp_host: ""})
      assert :ok = Mailer.apply_settings(s)
      assert Application.get_env(:craftplan, Mailer) == original
    end
  end

  describe "apply_settings/1 SendGrid" do
    test "configures SendGrid adapter" do
      s = settings(%{email_provider: :sendgrid, email_api_key: "SG.test_key"})
      assert :ok = Mailer.apply_settings(s)

      config = Application.get_env(:craftplan, Mailer)
      assert config[:adapter] == Swoosh.Adapters.SendGrid
      assert config[:api_key] == "SG.test_key"
    end

    test "skips when API key is blank" do
      original = Application.get_env(:craftplan, Mailer)
      s = settings(%{email_provider: :sendgrid, email_api_key: ""})
      assert :ok = Mailer.apply_settings(s)
      assert Application.get_env(:craftplan, Mailer) == original
    end
  end

  describe "apply_settings/1 Postmark" do
    test "configures Postmark adapter" do
      s = settings(%{email_provider: :postmark, email_api_key: "pm_test_key"})
      assert :ok = Mailer.apply_settings(s)

      config = Application.get_env(:craftplan, Mailer)
      assert config[:adapter] == Swoosh.Adapters.Postmark
      assert config[:api_key] == "pm_test_key"
    end
  end

  describe "apply_settings/1 Brevo" do
    test "configures Brevo adapter" do
      s = settings(%{email_provider: :brevo, email_api_key: "xkeysib-test"})
      assert :ok = Mailer.apply_settings(s)

      config = Application.get_env(:craftplan, Mailer)
      assert config[:adapter] == Swoosh.Adapters.Brevo
      assert config[:api_key] == "xkeysib-test"
    end
  end

  describe "apply_settings/1 Mailgun" do
    test "configures Mailgun adapter with domain" do
      s =
        settings(%{
          email_provider: :mailgun,
          email_api_key: "key-test",
          email_api_domain: "mg.example.com"
        })

      assert :ok = Mailer.apply_settings(s)

      config = Application.get_env(:craftplan, Mailer)
      assert config[:adapter] == Swoosh.Adapters.Mailgun
      assert config[:api_key] == "key-test"
      assert config[:domain] == "mg.example.com"
    end
  end

  describe "apply_settings/1 Amazon SES" do
    test "configures Amazon SES adapter" do
      s =
        settings(%{
          email_provider: :amazon_ses,
          email_api_key: "AKIAIOSFODNN7EXAMPLE",
          email_api_secret: "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY",
          email_api_region: "eu-west-1"
        })

      assert :ok = Mailer.apply_settings(s)

      config = Application.get_env(:craftplan, Mailer)
      assert config[:adapter] == Swoosh.Adapters.AmazonSES
      assert config[:access_key] == "AKIAIOSFODNN7EXAMPLE"
      assert config[:secret] == "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY"
      assert config[:region] == "eu-west-1"
    end

    test "skips when access key or secret is missing" do
      original = Application.get_env(:craftplan, Mailer)
      s = settings(%{email_provider: :amazon_ses, email_api_key: "AKIA", email_api_secret: ""})
      assert :ok = Mailer.apply_settings(s)
      assert Application.get_env(:craftplan, Mailer) == original
    end
  end
end
