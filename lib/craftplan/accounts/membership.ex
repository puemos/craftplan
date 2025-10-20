defmodule Craftplan.Accounts.Membership do
  @moduledoc """
  Join resource connecting users to organizations with per-tenant roles.
  """
  use Ash.Resource,
    otp_app: :craftplan,
    domain: Craftplan.Accounts,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table "accounts_memberships"
    repo Craftplan.Repo
  end

  actions do
    defaults [:read]

    create :create do
      primary? true
      accept [:organization_id, :user_id, :role, :status]
    end

    update :update do
      accept [:role, :status]
    end

    read :for_user do
      argument :organization_id, :uuid, allow_nil?: false
      argument :user_id, :uuid, allow_nil?: false
      get? true
      filter expr(organization_id == ^arg(:organization_id) and user_id == ^arg(:user_id))
    end

    read :list_for_user do
      argument :user_id, :uuid, allow_nil?: false
      filter expr(user_id == ^arg(:user_id))
    end
  end

  policies do
    policy action_type(:read) do
      authorize_if expr(^actor(:organization_id) == organization_id)
    end

    policy action_type(:create) do
      authorize_if expr(
                     ^actor(:organization_id) == organization_id and
                       ^actor(:role) in [:owner, :admin]
                   )
    end

    policy action_type([:update, :destroy]) do
      authorize_if expr(^actor(:organization_id) == organization_id and ^actor(:role) == :owner)
    end
  end

  multitenancy do
    strategy :attribute
    attribute :organization_id
  end

  attributes do
    uuid_primary_key :id

    attribute :organization_id, :uuid do
      allow_nil? false
      public? true
    end

    attribute :user_id, :uuid do
      allow_nil? false
      public? true
    end

    attribute :role, Craftplan.Accounts.Membership.Types.Role do
      allow_nil? false
      default :owner
      public? true
    end

    attribute :status, Craftplan.Accounts.Membership.Types.Status do
      allow_nil? false
      default :active
      public? true
    end

    timestamps()
  end

  relationships do
    belongs_to :organization, Craftplan.Organizations.Organization do
      attribute_type :uuid
      allow_nil? false
      destination_attribute :id
      source_attribute :organization_id
    end

    belongs_to :user, Craftplan.Accounts.User do
      attribute_type :uuid
      allow_nil? false
      destination_attribute :id
      source_attribute :user_id
    end
  end

  identities do
    identity :unique_membership, [:organization_id, :user_id]
  end
end
