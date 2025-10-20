defmodule Craftplan.Organizations.Provisioning do
  @moduledoc """
  Service module responsible for bootstrapping new organizations with sensible defaults.
  """

  alias Ash.Changeset
  alias Craftplan.Organizations.Organization

  @type provision_attrs :: %{
          optional(:slug) => String.t(),
          required(:name) => String.t(),
          optional(:billing_plan) => atom(),
          optional(:status) => atom(),
          optional(:preferences) => map(),
          optional(:timezone) => String.t(),
          optional(:locale) => String.t(),
          optional(:branding) => map()
        }

  @doc """
  Provision a new organization and hydrate preference metadata.

  Additional convenience keys such as `:timezone`, `:locale`, and `:branding`
  are merged into the stored preferences map.
  """
  @spec provision(provision_attrs()) ::
          {:ok, Ash.Resource.record()} | {:error, Ash.Error.t()}
  def provision(attrs) when is_map(attrs) do
    attrs
    |> normalize_attributes()
    |> create_organization()
  end

  defp create_organization(attrs) do
    Organization
    |> Changeset.for_create(:create, attrs)
    |> Ash.create(authorize?: false)
  end

  defp normalize_attributes(attrs) do
    preferences =
      attrs
      |> Map.get(:preferences, %{})
      |> Map.put_new("timezone", Map.get(attrs, :timezone, "UTC"))
      |> Map.put_new("locale", Map.get(attrs, :locale, "en"))
      |> maybe_merge_branding(Map.get(attrs, :branding))

    attrs
    |> Map.take([:name, :billing_plan, :status])
    |> Map.put(:slug, Map.get(attrs, :slug) || slugify!(Map.fetch!(attrs, :name)))
    |> Map.put(:preferences, preferences)
  end

  defp maybe_merge_branding(preferences, nil), do: preferences

  defp maybe_merge_branding(preferences, branding) when is_map(branding) do
    Map.put_new(preferences, "branding", branding)
  end

  defp slugify!(name) do
    name
    |> String.normalize(:nfd)
    |> String.replace(~r/\p{Mn}/u, "")
    |> String.downcase()
    |> String.replace(~r/[^a-z0-9]+/u, "-")
    |> String.trim("-")
    |> case do
      <<>> -> raise ArgumentError, "cannot derive slug from blank organization name"
      slug -> slug
    end
  end
end
