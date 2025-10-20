defmodule CraftplanWeb.Plugs.LoadOrganizationTest do
  use CraftplanWeb.ConnCase, async: true

  alias Craftplan.Organizations.Provisioning
  alias CraftplanWeb.Plugs.LoadOrganization

  setup do
    {:ok, organization} =
      Provisioning.provision(%{
        name: "Test Bakery",
        slug: "test-bakery",
        timezone: "Etc/UTC",
        locale: "en"
      })

    %{organization: organization}
  end

  test "assigns organization context and sets tenant metadata", %{
    conn: conn,
    organization: organization
  } do
    conn =
      conn
      |> Map.put(:path_params, %{"organization_slug" => organization.slug})
      |> LoadOrganization.call(%{})

    assert conn.status != 404
    assert conn.assigns.organization.id == organization.id
    assert conn.assigns.organization_slug == organization.slug
    assert conn.assigns.organization_base_path == "/app/#{organization.slug}"

    assert get_session(conn, "organization_id") == organization.id
    assert get_session(conn, "organization_slug") == organization.slug
    assert get_session(conn, "organization_base_path") == "/app/#{organization.slug}"

    assert Ash.PlugHelpers.get_tenant(conn) == organization.id
    assert conn.assigns.organization_actor == %{organization_id: organization.id}
    assert Ash.PlugHelpers.get_actor(conn) == %{organization_id: organization.id}

    context = Ash.PlugHelpers.get_context(conn)
    assert %{organization_context: org_ctx} = context
    assert org_ctx.organization.id == organization.id
  end

  test "merges current user details into actor map", %{conn: conn, organization: organization} do
    user = Craftplan.Test.AuthHelpers.register_user!(role: :staff)

    conn =
      conn
      |> assign(:current_user, user)
      |> Map.put(:path_params, %{"organization_slug" => organization.slug})
      |> LoadOrganization.call(%{})

    actor = Ash.PlugHelpers.get_actor(conn)

    assert actor.organization_id == organization.id
    assert actor.role == :staff
    assert actor.id == user.id
    assert conn.assigns.organization_actor == actor
  end

  test "halts with 404 when organization slug is missing", %{conn: conn} do
    conn = LoadOrganization.call(conn, %{})

    assert conn.status == 404
    assert conn.halted
  end

  test "halts with 404 when organization slug cannot be found", %{conn: conn} do
    conn =
      conn
      |> Map.put(:path_params, %{"organization_slug" => "missing"})
      |> LoadOrganization.call(%{})

    assert conn.status == 404
    assert conn.halted
  end
end
