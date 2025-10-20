defmodule Craftplan.Organizations do
  @moduledoc false
  use Ash.Domain

  alias Ash.Changeset
  alias Ash.Query
  alias Craftplan.Types.OrganizationContext

  @doc """
  Construct an organization context struct from an organization record and optional overrides.
  """
  @spec build_organization_context(Ash.Resource.record(), keyword()) :: OrganizationContext.t()
  def build_organization_context(organization, opts \\ []) do
    %OrganizationContext{
      organization: organization,
      features: Keyword.get(opts, :features, []),
      timezone: Keyword.get(opts, :timezone, Map.get(organization.preferences, "timezone", "UTC")),
      locale: Keyword.get(opts, :locale, Map.get(organization.preferences, "locale", "en")),
      billing: Keyword.get(opts, :billing, %{}),
      branding: Keyword.get(opts, :branding, Map.get(organization.preferences, "branding", %{}))
    }
  end

  @doc """
  Normalize a changeset, query, or option list to operate under the organization's tenant.

  Accepts an `Ash.Changeset`, `Ash.Query`, or keyword options list (for passing to
  domain calls) and applies the appropriate tenant identifier. The organization can
  be provided as a struct or bare UUID.
  """
  @spec put_tenant(Changeset.t(), Ash.Resource.record() | binary()) :: Changeset.t()
  @spec put_tenant(Query.t(), Ash.Resource.record() | binary()) :: Query.t()
  @spec put_tenant(keyword(), Ash.Resource.record() | binary()) :: keyword()
  def put_tenant(%Changeset{} = changeset, organization),
    do: Changeset.set_tenant(changeset, organization_id(organization))

  def put_tenant(%Query{} = query, organization), do: Query.set_tenant(query, organization_id(organization))

  def put_tenant(opts, organization) when is_list(opts), do: Keyword.put(opts, :tenant, organization_id(organization))

  @doc """
  Ensure an actor map includes the provided organization's identifier.

  Useful when invoking Ash actions directly in tests or background workers where
  we construct the actor manually. If `nil` is provided, a new actor map is returned.
  """
  @spec put_actor(map() | nil, Ash.Resource.record() | binary()) :: map()
  def put_actor(nil, organization), do: %{organization_id: organization_id(organization)}

  def put_actor(actor, organization) when is_struct(actor) do
    actor
    |> Map.from_struct()
    |> Map.put(:organization_id, organization_id(organization))
  end

  def put_actor(actor, organization) when is_map(actor) do
    Map.put(actor, :organization_id, organization_id(organization))
  end

  resources do
    resource Craftplan.Organizations.Organization do
      define :create_organization, action: :create
      define :update_organization, action: :update
      define :list_organizations, action: :read
      define :list_active_organizations, action: :list_active
      define :get_organization_by_slug, action: :lookup_by_slug
      define :get_organization_by_id, action: :read, get_by: [:id]
    end
  end

  defp organization_id(%{id: id}) when is_binary(id), do: id
  defp organization_id(id) when is_binary(id), do: id
end
