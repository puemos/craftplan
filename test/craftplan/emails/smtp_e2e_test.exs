defmodule Craftplan.Emails.SmtpE2eTest do
  @moduledoc """
  End-to-end email tests that send real emails through Mailpit.

  Prerequisites:
    docker-compose up -d mailpit

  Run with:
    mix test --include e2e
  """

  use Craftplan.DataCase, async: false

  alias Craftplan.Test.Factory
  alias Craftplan.Test.Mailpit
  alias Swoosh.Adapters.Test

  @moduletag :e2e

  setup do
    # Bootstrap a settings record (needed by email sender lookup)
    {:ok, settings} = Craftplan.Settings.init()

    # Switch to SMTP adapter pointing at Mailpit and clear inbox
    Mailpit.setup_smtp!()
    Mailpit.delete_all!()

    on_exit(fn ->
      Application.put_env(:craftplan, Craftplan.Mailer, adapter: Test)
    end)

    %{settings: settings}
  end

  describe "order confirmation email" do
    test "delivers order confirmation to customer via SMTP" do
      # Temporarily use Test adapter for factory calls that trigger auth emails
      Application.put_env(:craftplan, Craftplan.Mailer, adapter: Test)

      customer = Factory.create_customer!(%{email: "order-test@example.com"})
      product = Factory.create_product!()

      order =
        Factory.create_order_with_items!(customer, [
          %{product_id: product.id, quantity: 3, unit_price: Money.new("10.00", :USD)}
        ])

      # Reload with customer and items — customer read policy requires staff actor
      actor = staff_actor()
      order = Ash.load!(order, [items: [product: [:name, :sku]], customer: []], actor: actor)

      # Switch back to SMTP and clear any stray messages
      Mailpit.setup_smtp!()
      Mailpit.delete_all!()

      assert {:ok, _} = Craftplan.Orders.Emails.deliver_order_confirmation(order)

      assert {:ok, [message | _]} =
               Mailpit.assert_email_received("to:order-test@example.com")

      assert message["Subject"] =~ order.reference
    end
  end

  describe "password reset email" do
    test "delivers reset password email via SMTP" do
      recipient = "reset-test-#{System.unique_integer([:positive])}@example.com"

      Craftplan.Accounts.Emails.deliver_reset_password_instructions(
        %{email: recipient},
        "https://craftplan.test/password-reset/fake-token"
      )

      assert {:ok, [message | _]} =
               Mailpit.assert_email_received("to:#{recipient}")

      assert message["Subject"] =~ "Reset"

      full = Mailpit.get_message(message["ID"])
      assert full["HTML"] =~ "fake-token"
    end
  end

  describe "custom sender settings" do
    test "uses configured from name and address", %{settings: settings} do
      # Update requires admin actor — create with Test adapter to avoid SMTP for auth emails
      Application.put_env(:craftplan, Craftplan.Mailer, adapter: Test)
      actor = admin_actor()

      settings
      |> Ash.Changeset.for_update(:update, %{
        email_from_name: "My Bakery",
        email_from_address: "orders@mybakery.com"
      })
      |> Ash.update!(actor: actor)

      # Switch back to SMTP and clear inbox
      Mailpit.setup_smtp!()
      Mailpit.delete_all!()

      recipient = "sender-test-#{System.unique_integer([:positive])}@example.com"

      Craftplan.Accounts.Emails.deliver_reset_password_instructions(
        %{email: recipient},
        "https://craftplan.test/password-reset/token123"
      )

      assert {:ok, [message | _]} =
               Mailpit.assert_email_received("to:#{recipient}")

      full = Mailpit.get_message(message["ID"])

      from = full["From"]
      assert from["Name"] == "My Bakery"
      assert from["Address"] == "orders@mybakery.com"
    end
  end

  describe "dynamic SMTP settings" do
    test "applies SMTP config from database settings and delivers email", %{settings: settings} do
      # Start with the Test adapter — no SMTP configured yet
      Application.put_env(:craftplan, Craftplan.Mailer, adapter: Test)
      actor = admin_actor()

      # Simulate a user saving SMTP settings pointing at Mailpit
      updated =
        settings
        |> Ash.Changeset.for_update(:update, %{
          smtp_host: "localhost",
          smtp_port: 1025,
          smtp_username: nil,
          smtp_password: nil,
          smtp_tls: :never
        })
        |> Ash.update!(actor: actor)

      # Apply settings the same way the app does (on boot and on form save)
      Craftplan.Mailer.apply_settings(updated)

      # Verify the adapter was switched to SMTP with correct relay
      mailer_config = Application.get_env(:craftplan, Craftplan.Mailer)
      assert mailer_config[:adapter] == Swoosh.Adapters.SMTP
      assert mailer_config[:relay] == "localhost"
      assert mailer_config[:port] == 1025

      Mailpit.delete_all!()

      recipient = "dynamic-smtp-#{System.unique_integer([:positive])}@example.com"

      Craftplan.Accounts.Emails.deliver_reset_password_instructions(
        %{email: recipient},
        "https://craftplan.test/password-reset/dynamic-test"
      )

      assert {:ok, [message | _]} =
               Mailpit.assert_email_received("to:#{recipient}")

      full = Mailpit.get_message(message["ID"])
      assert full["HTML"] =~ "dynamic-test"
    end

    test "ignores empty smtp_host and does not switch adapter", %{settings: settings} do
      Application.put_env(:craftplan, Craftplan.Mailer, adapter: Test)
      actor = admin_actor()

      updated =
        settings
        |> Ash.Changeset.for_update(:update, %{
          smtp_host: "",
          smtp_port: 1025
        })
        |> Ash.update!(actor: actor)

      Craftplan.Mailer.apply_settings(updated)

      # Adapter should remain unchanged (Test)
      mailer_config = Application.get_env(:craftplan, Craftplan.Mailer)
      assert mailer_config[:adapter] == Test
    end
  end
end
