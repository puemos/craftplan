defmodule Craftplan.Accounts.SignupTest do
  use Craftplan.DataCase, async: true

  alias Ash.Query
  alias Craftplan.Accounts.Signup
  alias Craftplan.Accounts.Token

  describe "signup/1" do
    test "creates an organization, admin user, membership, and token" do
      attrs = %{
        organization_name: "Sunrise Bakery",
        organization_slug: "sunrise-bakery",
        admin_email: "owner@example.com",
        admin_password: "Sup3rSecret!",
        admin_password_confirmation: "Sup3rSecret!"
      }

      assert {:ok, result} = Signup.signup(attrs)

      assert result.organization.name == "Sunrise Bakery"
      assert result.organization.slug == "sunrise-bakery"

      assert to_string(result.user.email) == "owner@example.com"
      assert result.user.role == :admin

      assert result.membership.organization_id == result.organization.id
      assert result.membership.user_id == result.user.id
      assert result.membership.role == :owner
      assert result.membership.status == :active

      assert is_binary(result.token)

      {:ok, [%{extra_data: extra_data}]} =
        Token
        |> Query.for_read(:get_token, %{token: result.token})
        |> Ash.read(authorize?: false, context: %{private: %{ash_authentication?: true}})

      assert extra_data["organization_id"] == result.organization.id
    end
  end
end
