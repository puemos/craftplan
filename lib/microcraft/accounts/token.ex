defmodule Microcraft.Accounts.Token do
  @moduledoc false
  use Ash.Resource,
    otp_app: :microcraft,
    domain: Microcraft.Accounts,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [AshAuthentication.TokenResource]

  postgres do
    table "accounts_tokens"
    repo Microcraft.Repo
  end

  actions do
    defaults [:read]

    read :expired do
      description "Look up all expired tokens."
      filter expr(expires_at < now())
    end

    read :get_token do
      description "Look up a token by JTI or token, and an optional purpose."
      get? true
      argument :token, :string, sensitive?: true
      argument :jti, :string, sensitive?: true
      argument :purpose, :string, sensitive?: false

      prepare AshAuthentication.TokenResource.GetTokenPreparation
    end

    action :revoked? do
      description "Returns true if a revocation token is found for the provided token"
      argument :token, :string, sensitive?: true, allow_nil?: false
      argument :jti, :string, sensitive?: true, allow_nil?: false

      run AshAuthentication.TokenResource.IsRevoked
    end

    create :revoke_token do
      description "Revoke a token. Creates a revocation token corresponding to the provided token."
      accept [:extra_data]
      argument :token, :string, allow_nil?: false, sensitive?: true

      change AshAuthentication.TokenResource.RevokeTokenChange
    end

    create :store_token do
      description "Stores a token used for the provided purpose."
      accept [:extra_data, :purpose]
      argument :token, :string, allow_nil?: false, sensitive?: true
      change AshAuthentication.TokenResource.StoreTokenChange
    end

    destroy :expunge_expired do
      description "Deletes expired tokens."
      change filter expr(expires_at < now())
    end
  end

  policies do
    bypass AshAuthentication.Checks.AshAuthenticationInteraction do
      description "AshAuthentication can interact with the token resource"
      authorize_if always()
    end

    policy always() do
      description "No one aside from AshAuthentication can interact with the tokens resource."
      forbid_if always()
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :jti, :string do
      primary_key? true
      public? true
      allow_nil? false
      sensitive? true
    end

    attribute :subject, :string do
      allow_nil? false
    end

    attribute :expires_at, :utc_datetime do
      allow_nil? false
    end

    attribute :purpose, :string do
      allow_nil? false
      public? true
    end

    attribute :extra_data, :map do
      public? true
    end

    timestamps()
  end
end
