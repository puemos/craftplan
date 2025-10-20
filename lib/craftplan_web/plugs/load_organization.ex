defmodule CraftplanWeb.Plugs.LoadOrganization do
  @moduledoc """
  Resolve the organization from the base path and assign multitenancy context.

  Expects routes to include a `:organization_slug` path segment. When present it
  loads the organization, stores a lightweight context in the session, and sets
  the Ash actor/tenant for downstream reads and writes.
  """
  @behaviour Plug

  import Plug.Conn

  alias Craftplan.Accounts
  alias Craftplan.Organizations
  alias CraftplanWeb.ErrorHTML
  alias Phoenix.Controller

  @impl Plug
  def init(opts), do: opts

  @impl Plug
  def call(conn, _opts) do
    with {:ok, slug} <- fetch_slug(conn),
         {:ok, organization} <- get_organization(slug),
         {:ok, membership} <- ensure_membership(conn.assigns[:current_user], organization) do
      context = Organizations.build_organization_context(organization)

      actor = Organizations.put_actor(conn.assigns[:current_user], organization, membership)

      conn
      |> assign(:organization, organization)
      |> assign(:organization_context, context)
      |> assign(:organization_slug, organization.slug)
      |> assign(:organization_base_path, "/app/#{organization.slug}")
      |> assign(:current_membership, membership)
      |> assign(:organization_actor, actor)
      |> put_session_values(organization, membership)
      |> Ash.PlugHelpers.set_tenant(organization.id)
      |> Ash.PlugHelpers.set_actor(actor)
      |> Ash.PlugHelpers.set_context(%{organization_context: context})
    else
      {:error, :missing_slug} ->
        send_not_found(conn)

      {:error, :not_found} ->
        send_not_found(conn)

      {:error, :not_member} ->
        send_not_found(conn)
    end
  end

  defp fetch_slug(%Plug.Conn{path_params: %{"organization_slug" => slug}}) when slug != "" do
    {:ok, slug}
  end

  defp fetch_slug(%Plug.Conn{}), do: {:error, :missing_slug}

  defp get_organization(slug) do
    case Organizations.get_organization_by_slug(%{slug: slug}) do
      {:ok, %_{} = organization} -> {:ok, organization}
      {:ok, nil} -> {:error, :not_found}
      {:error, _} -> {:error, :not_found}
    end
  end

  defp ensure_membership(nil, _organization), do: {:ok, nil}

  defp ensure_membership(%{id: user_id}, %{id: organization_id}) do
    case Accounts.get_membership(organization_id, user_id,
           tenant: organization_id,
           authorize?: false
         ) do
      {:ok, %_{} = membership} -> {:ok, membership}
      {:ok, nil} -> {:error, :not_member}
      {:error, _} -> {:error, :not_member}
    end
  end

  defp put_session_values(conn, organization, membership) do
    conn
    |> put_session("organization_id", organization.id)
    |> put_session("organization_slug", organization.slug)
    |> put_session("organization_base_path", "/app/#{organization.slug}")
    |> maybe_put_membership_session(membership)
  end

  defp maybe_put_membership_session(conn, nil) do
    conn
    |> delete_session("membership_id")
    |> delete_session("membership_role")
  end

  defp maybe_put_membership_session(conn, membership) do
    conn
    |> put_session("membership_id", membership.id)
    |> put_session("membership_role", Atom.to_string(membership.role))
  end

  defp send_not_found(conn) do
    conn
    |> Controller.put_view(ErrorHTML)
    |> Plug.Conn.put_status(:not_found)
    |> Controller.render("404.html")
    |> halt()
  end
end
