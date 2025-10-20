defmodule CraftplanWeb.AuthController do
  use CraftplanWeb, :controller
  use AshAuthentication.Phoenix.Controller

  alias Craftplan.Accounts
  alias Craftplan.Accounts.Token
  alias Craftplan.Organizations

  def success(conn, activity, user, _token) do
    return_to = get_session(conn, :return_to) || ~p"/"

    message =
      case activity do
        {:confirm_new_user, :confirm} -> "Your email address has now been confirmed"
        {:password, :reset} -> "Your password has successfully been reset"
        _ -> "You are now signed in"
      end

    with {:ok, slug} <- fetch_slug(conn),
         {:ok, organization} <- fetch_organization(slug),
         {:ok, membership} <- fetch_membership(user, organization),
         {:ok, issued_user, session_token} <- issue_session_token(user, organization) do
      conn
      |> delete_session(:return_to)
      |> store_in_session(issued_user)
      |> put_session("organization_slug", organization.slug)
      |> put_session("organization_id", organization.id)
      |> put_session("organization_base_path", "/app/#{organization.slug}")
      |> put_session("membership_id", membership.id)
      |> put_session("membership_role", Atom.to_string(membership.role))
      |> assign(:current_user, issued_user)
      |> assign(:current_membership, membership)
      |> assign(:session_token, session_token)
      |> put_flash(:info, message)
      |> redirect(to: organization_base_path(return_to, organization))
    else
      {:error, :missing_slug} ->
        conn
        |> delete_session(:return_to)
        |> put_flash(:error, "Please provide an organization slug to sign in.")
        |> redirect(to: ~p"/sign-in")

      {:error, :organization_not_found} ->
        conn
        |> delete_session(:return_to)
        |> put_flash(:error, "We could not find that organization.")
        |> redirect(to: ~p"/sign-in")

      {:error, :membership_not_found} ->
        conn
        |> delete_session(:return_to)
        |> put_flash(:error, "You do not have access to that organization.")
        |> redirect(to: ~p"/sign-in")

      {:error, _reason} ->
        conn
        |> delete_session(:return_to)
        |> put_flash(:error, "We were unable to complete the sign-in request.")
        |> redirect(to: ~p"/sign-in")
    end
  end

  def failure(conn, activity, reason) do
    message =
      case {activity, reason} do
        {{:magic_link, _},
         %AshAuthentication.Errors.AuthenticationFailed{
           caused_by: %Ash.Error.Forbidden{
             errors: [%AshAuthentication.Errors.CannotConfirmUnconfirmedUser{}]
           }
         }} ->
          """
          You have already signed in another way, but have not confirmed your account.
          You can confirm your account using the link we sent to you, or by resetting your password.
          """

        _ ->
          "Incorrect email or password"
      end

    conn
    |> put_flash(:error, message)
    |> redirect(to: ~p"/sign-in")
  end

  def sign_out(conn, _params) do
    return_to = get_session(conn, :return_to) || ~p"/"

    conn
    |> clear_session(:craftplan)
    |> put_flash(:info, "You are now signed out")
    |> redirect(to: return_to)
  end

  defp fetch_slug(%Plug.Conn{params: params} = conn) do
    slug =
      params["organization_slug"] ||
        (params["organization"] && params["organization"]["slug"]) ||
        get_in(params, ["user", "organization_slug"]) ||
        get_session(conn, "organization_slug")

    if slug in [nil, ""] do
      {:error, :missing_slug}
    else
      {:ok, slug}
    end
  end

  defp fetch_organization(slug) do
    case Organizations.get_organization_by_slug(%{slug: slug}) do
      {:ok, %_{} = organization} -> {:ok, organization}
      {:ok, nil} -> {:error, :organization_not_found}
      {:error, _} -> {:error, :organization_not_found}
    end
  end

  defp fetch_membership(user, organization) do
    case Accounts.get_membership(organization.id, user.id,
           tenant: organization.id,
           authorize?: false
         ) do
      {:ok, %_{} = membership} -> {:ok, membership}
      {:ok, nil} -> {:error, :membership_not_found}
      {:error, _} -> {:error, :membership_not_found}
    end
  end

  defp issue_session_token(user, organization) do
    with {:ok, token, _claims} <-
           AshAuthentication.Jwt.token_for_user(
             user,
             %{"organization_id" => organization.id},
             [],
             %{private: %{ash_authentication?: true}}
           ),
         {:ok, _} <- store_token_record(token, organization.id) do
      {:ok, Ash.Resource.put_metadata(user, :token, token), token}
    end
  end

  defp store_token_record(token, organization_id) do
    Token
    |> Ash.Changeset.for_create(:store_token, %{
      token: token,
      purpose: "user",
      extra_data: %{"organization_id" => organization_id}
    })
    |> Ash.create(
      authorize?: false,
      context: %{private: %{ash_authentication?: true}},
      upsert?: true
    )
  end

  defp organization_base_path(return_to, organization) when is_binary(return_to) do
    if String.starts_with?(return_to, "/app/") do
      return_to
    else
      "/app/#{organization.slug}"
    end
  end

  defp organization_base_path(_return_to, organization), do: "/app/#{organization.slug}"
end
