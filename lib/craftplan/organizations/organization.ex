defmodule Craftplan.Organizations.Organization do
  @moduledoc """
  Ash resource representing a customer organization within Craftplan.
  """
  use Ash.Resource,
    otp_app: :craftplan,
    domain: Craftplan.Organizations,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table "organizations"
    repo Craftplan.Repo
  end

  actions do
    defaults [:read]

    create :create do
      primary? true
      accept [:name, :slug, :status, :billing_plan, :preferences]
    end

    update :update do
      accept [:name, :status, :billing_plan, :preferences]
    end

    read :lookup_by_slug do
      argument :slug, :string, allow_nil?: false
      filter expr(slug == ^arg(:slug))
      get? true
    end

    read :list_active do
      filter expr(status == :active)
    end
  end

  policies do
    policy action_type(:read) do
      authorize_if always()
    end

    policy action_type([:create, :update, :destroy]) do
      authorize_if expr(^actor(:role) in [:admin])
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :name, :string do
      allow_nil? false
      public? true
    end

    attribute :slug, :string do
      allow_nil? false
      public? true
      constraints match: ~r/^[a-z0-9-]+$/
    end

    attribute :status, :atom do
      allow_nil? false
      default :active
      constraints one_of: [:active, :suspended]
      public? true
    end

    attribute :billing_plan, :atom do
      allow_nil? false
      default :starter
      constraints one_of: [:starter, :growth, :enterprise]
      public? true
    end

    attribute :preferences, :map do
      allow_nil? false
      default %{}
      public? true
    end
  end

  relationships do
    has_many :memberships, Craftplan.Accounts.Membership do
      destination_attribute :organization_id
    end
  end

  calculations do
    calculate :branding_color, :string do
      calculation fn record, _context ->
        {:ok, get_in(record.preferences, ["branding", "primary_color"])}
      end
    end
  end

  identities do
    identity :slug, [:slug]
  end
end
