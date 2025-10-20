defmodule CraftplanWeb.AuthControllerTest do
  use CraftplanWeb.ConnCase, async: true

  alias Ash.Changeset
  alias Ash.Query
  alias Craftplan.Accounts.Membership
  alias Craftplan.Accounts.Token
  alias Craftplan.Organizations.Provisioning

  setup do
    {:ok, organization} =
      Provisioning.provision(%{
        name: "Test Bakery",
        slug: "test-bakery"
      })

    %{organization: organization}
  end

  test "success stores organization and membership context in the session", %{
    conn: conn,
    organization: organization
  } do
    user = Craftplan.Test.AuthHelpers.register_user!(role: :admin)

    {:ok, membership} =
      Membership
      |> Changeset.for_create(:create, %{
        organization_id: organization.id,
        user_id: user.id,
        role: :owner,
        status: :active
      })
      |> Ash.create(authorize?: false, tenant: organization.id)

    conn =
      conn
      |> Plug.Test.init_test_session(%{return_to: "/"})
      |> Phoenix.Controller.fetch_flash()
      |> Map.put(:params, %{"user" => %{"organization_slug" => organization.slug}})

    conn =
      CraftplanWeb.AuthController.success(
        conn,
        {:password, :sign_in},
        user,
        user.__metadata__.token
      )

    assert redirected_to(conn) == "/app/#{organization.slug}"
    assert get_session(conn, "organization_id") == organization.id
    assert get_session(conn, "organization_slug") == organization.slug
    assert get_session(conn, "organization_base_path") == "/app/#{organization.slug}"
    assert get_session(conn, "membership_role") == Atom.to_string(membership.role)
    assert get_session(conn, "membership_id") == membership.id

    assert conn.assigns.current_user.id == user.id
    assert conn.assigns.current_membership.id == membership.id
    assert conn.assigns.session_token

    {:ok, [%{extra_data: extra_data}]} =
      Token
      |> Query.for_read(:get_token, %{token: conn.assigns.session_token})
      |> Ash.read(authorize?: false, context: %{private: %{ash_authentication?: true}})

    assert extra_data["organization_id"] == organization.id
  end
end
