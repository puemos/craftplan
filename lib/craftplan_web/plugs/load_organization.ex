defmodule CraftplanWeb.Plugs.LoadOrganization do
  @moduledoc """
  Resolve the organization from the base path and assign multitenancy context.

  Expects routes to include a `:organization_slug` path segment. When present it
  loads the organization, stores a lightweight context in the session, and sets
  the Ash actor/tenant for downstream reads and writes.
  """
  @behaviour Plug

  import Plug.Conn

  alias Craftplan.Organizations
  alias CraftplanWeb.ErrorHTML
  alias Phoenix.Controller

  @session_keys ["organization_id", "organization_slug", "organization_base_path"]

  @impl Plug
  def init(opts), do: opts

  @impl Plug
  def call(conn, _opts) do
    with {:ok, slug} <- fetch_slug(conn),
         {:ok, organization} <- get_organization(slug) do
      context = Organizations.build_organization_context(organization)

      actor = Organizations.put_actor(conn.assigns[:current_user], organization)

      conn
      |> assign(:organization, organization)
      |> assign(:organization_context, context)
      |> assign(:organization_slug, organization.slug)
      |> assign(:organization_base_path, "/app/#{organization.slug}")
      |> assign(:organization_actor, actor)
      |> put_session_values(organization)
      |> Ash.PlugHelpers.set_tenant(organization.id)
      |> Ash.PlugHelpers.set_actor(actor)
      |> Ash.PlugHelpers.set_context(%{organization_context: context})
    else
      {:error, :missing_slug} ->
        send_not_found(conn)

      {:error, :not_found} ->
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

  defp put_session_values(conn, organization) do
    Enum.reduce(@session_keys, conn, fn key, acc ->
      case key do
        "organization_id" -> put_session(acc, key, organization.id)
        "organization_slug" -> put_session(acc, key, organization.slug)
        "organization_base_path" -> put_session(acc, key, "/app/#{organization.slug}")
      end
    end)
  end

  defp send_not_found(conn) do
    conn
    |> Controller.put_view(ErrorHTML)
    |> Plug.Conn.put_status(:not_found)
    |> Controller.render("404.html")
    |> halt()
  end
end
