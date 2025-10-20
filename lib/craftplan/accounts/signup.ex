defmodule Craftplan.Accounts.Signup do
  @moduledoc """
  Self-service onboarding flow for creating an organization and its first admin.
  """

  alias Ash.Changeset
  alias AshAuthentication.Strategy.Password
  alias Craftplan.Accounts.Membership
  alias Craftplan.Accounts.Token
  alias Craftplan.Accounts.User
  alias Craftplan.Organizations.Provisioning
  alias Craftplan.Repo

  @required_user_fields [:admin_email, :admin_password, :admin_password_confirmation]
  @required_org_fields [:organization_name]

  @type signup_attrs :: %{
          required(:organization_name) => String.t(),
          optional(:organization_slug) => String.t(),
          required(:admin_email) => String.t(),
          required(:admin_password) => String.t(),
          required(:admin_password_confirmation) => String.t()
        }

  @doc """
  Provision a new organization and register its first admin user.

  Returns the created organization, user, membership, and a session token embedding
  the organization identifier.
  """
  @spec signup(signup_attrs()) ::
          {:ok,
           %{
             organization: Ash.Resource.record(),
             user: Ash.Resource.record(),
             membership: Ash.Resource.record(),
             token: String.t()
           }}
          | {:error, term()}
  def signup(attrs) when is_map(attrs) do
    fn ->
      with :ok <- validate_attrs(attrs),
           {:ok, organization} <- Provisioning.provision(organization_params(attrs)),
           {:ok, user} <- register_admin(attrs),
           {:ok, membership} <- create_membership(organization, user),
           {:ok, issued_user, token} <- issue_session_token(user, organization) do
        %{organization: organization, user: issued_user, membership: membership, token: token}
      else
        {:error, reason} -> Repo.rollback(reason)
      end
    end
    |> Repo.transaction()
    |> case do
      {:ok, result} -> {:ok, result}
      {:error, reason} -> {:error, reason}
    end
  end

  defp validate_attrs(attrs) do
    missing = Enum.reject(@required_user_fields ++ @required_org_fields, &present?(attrs, &1))

    case missing do
      [] -> :ok
      fields -> {:error, {:missing_fields, fields}}
    end
  end

  defp present?(attrs, key) do
    case Map.get(attrs, key) do
      value when is_binary(value) -> String.trim(value) != ""
      _ -> false
    end
  end

  defp organization_params(attrs) do
    %{
      name: Map.fetch!(attrs, :organization_name),
      slug: Map.get(attrs, :organization_slug)
    }
  end

  defp register_admin(attrs) do
    params = %{
      email: Map.fetch!(attrs, :admin_email),
      password: Map.fetch!(attrs, :admin_password),
      password_confirmation: Map.fetch!(attrs, :admin_password_confirmation),
      role: :admin
    }

    User
    |> Changeset.for_create(:register_with_password, params)
    |> Ash.create(
      context: %{
        strategy: Password,
        private: %{ash_authentication?: true}
      }
    )
  end

  defp create_membership(organization, user) do
    Membership
    |> Changeset.for_create(:create, %{
      organization_id: organization.id,
      user_id: user.id,
      role: :owner,
      status: :active
    })
    |> Ash.create(
      authorize?: false,
      tenant: organization.id
    )
  end

  defp issue_session_token(user, organization) do
    with {:ok, token, _claims} <-
           AshAuthentication.Jwt.token_for_user(
             user,
             %{"organization_id" => organization.id},
             [],
             %{private: %{ash_authentication?: true}}
           ),
         {:ok, _} <- store_token_record(token, organization.id) do
      {:ok, Ash.Resource.put_metadata(user, :token, token), token}
    end
  end

  defp store_token_record(token, organization_id) do
    Token
    |> Changeset.for_create(:store_token, %{
      token: token,
      purpose: "user",
      extra_data: %{"organization_id" => organization_id}
    })
    |> Ash.create(
      authorize?: false,
      context: %{private: %{ash_authentication?: true}},
      upsert?: true
    )
  end
end
