defmodule CraftplanWeb.LiveOrganization do
  @moduledoc """
  LiveView on-mount hook that injects organization context into the socket.
  """

  use CraftplanWeb, :verified_routes

  import Phoenix.Component, only: [assign: 3]

  alias Craftplan.Organizations

  def on_mount(:default, _params, session, socket) do
    case load_organization(session) do
      {:ok, organization} ->
        context = Organizations.build_organization_context(organization)

        socket
        |> assign(:organization, organization)
        |> assign(:organization_slug, organization.slug)
        |> assign(
          :organization_base_path,
          session["organization_base_path"] || "/app/#{organization.slug}"
        )
        |> assign(:organization_context, context)
        |> then(&{:cont, &1})

      {:error, :missing} ->
        {:halt, Phoenix.LiveView.redirect(socket, to: ~p"/")}

      {:error, :not_found} ->
        {:halt, Phoenix.LiveView.redirect(socket, to: ~p"/")}
    end
  end

  defp load_organization(%{"organization_id" => id}) when is_binary(id) do
    case Organizations.get_organization_by_id(id) do
      {:ok, %_{} = organization} -> {:ok, organization}
      {:ok, nil} -> {:error, :not_found}
      {:error, _} -> {:error, :not_found}
    end
  end

  defp load_organization(_session), do: {:error, :missing}

  @doc """
  Returns the organization-scoped base path (e.g. "/app/demo-bakery").

  Accepts a LiveView socket, assigns map, or plain string representing the
  base path. When no information is available, falls back to the empty string.
  """
  def base_path(%Phoenix.LiveView.Socket{} = socket), do: base_path(socket.assigns)

  def base_path(%{organization_base_path: base_path}) when is_binary(base_path) and base_path != "" do
    base_path
  end

  def base_path(%{organization_slug: slug}) when is_binary(slug) and slug != "" do
    "/app/#{slug}"
  end

  def base_path(base_path) when is_binary(base_path), do: base_path
  def base_path(_), do: ""

  @doc """
  Builds a path under the current organization's base path by appending the
  given `segments`. An optional query map or string may be provided.
  """
  def scoped_path(target, segments), do: scoped_path(target, segments, nil)

  def scoped_path(target, segments, query) do
    base_path = target |> base_path() |> String.trim_trailing("/")
    suffix = Enum.join(List.wrap(segments), "/")

    path =
      cond do
        base_path == "" and suffix == "" -> "/"
        base_path == "" -> "/" <> suffix
        suffix == "" -> base_path
        true -> base_path <> "/" <> suffix
      end

    case query do
      nil ->
        path

      query when is_binary(query) and query != "" ->
        path <> "?" <> query

      query when is_list(query) ->
        encoded = URI.encode_query(query)

        if encoded == "" do
          path
        else
          path <> "?" <> encoded
        end

      %{} = query_map ->
        encoded = URI.encode_query(query_map)

        if encoded == "" do
          path
        else
          path <> "?" <> encoded
        end

      _ ->
        path
    end
  end
end
