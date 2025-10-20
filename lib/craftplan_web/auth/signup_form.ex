defmodule CraftplanWeb.Auth.SignupForm do
  @moduledoc false
  use Ecto.Schema

  import Ecto.Changeset

  @primary_key false
  embedded_schema do
    field :organization_name, :string
    field :organization_slug, :string
    field :admin_email, :string
    field :admin_password, :string
    field :admin_password_confirmation, :string
  end

  @fields [
    :organization_name,
    :organization_slug,
    :admin_email,
    :admin_password,
    :admin_password_confirmation
  ]

  @doc false
  def changeset(form, attrs) do
    form
    |> cast(attrs, @fields)
    |> update_change(:organization_name, &normalize/1)
    |> update_change(:organization_slug, &normalize_slug/1)
    |> update_change(:admin_email, &normalize/1)
    |> validate_required([
      :organization_name,
      :admin_email,
      :admin_password,
      :admin_password_confirmation
    ])
    |> validate_length(:organization_name, min: 3)
    |> validate_slug(:organization_slug)
    |> validate_format(:admin_email, ~r/@/)
    |> validate_length(:admin_password, min: 8)
    |> validate_confirmation(:admin_password)
  end

  def apply(attrs) when is_map(attrs) do
    %__MODULE__{}
    |> changeset(attrs)
    |> apply_action(:insert)
  end

  defp normalize(nil), do: nil
  defp normalize(value) when is_binary(value), do: String.trim(value)
  defp normalize(value), do: value

  defp normalize_slug(nil), do: nil

  defp normalize_slug(value) when is_binary(value) do
    value
    |> String.trim()
    |> String.downcase()
    |> case do
      "" -> nil
      slug -> slug
    end
  end

  defp normalize_slug(value), do: value

  defp validate_slug(changeset, field) do
    case get_change(changeset, field) do
      nil ->
        changeset

      "" ->
        changeset

      slug ->
        changeset
        |> validate_length(field, min: 3)
        |> validate_format(field, ~r/^[a-z0-9\-]+$/)
        |> put_change(field, slug)
    end
  end
end
