defmodule CraftplanWeb.LiveUserAuth do
  @moduledoc """
  Helpers for authenticating users in LiveViews.
  """

  use CraftplanWeb, :verified_routes

  import Phoenix.Component

  alias Craftplan.Accounts

  def on_mount(:live_user_optional, _params, session, socket) do
    socket = ensure_membership(socket, session)

    if socket.assigns[:current_user] do
      {:cont, socket}
    else
      {:cont, socket |> assign(:current_user, nil) |> assign(:current_membership, nil)}
    end
  end

  def on_mount(:live_user_required, _params, session, socket) do
    socket = ensure_membership(socket, session)

    if socket.assigns[:current_user] do
      {:cont, socket}
    else
      {:halt, Phoenix.LiveView.redirect(socket, to: ~p"/sign-in")}
    end
  end

  def on_mount(:live_staff_required, _params, session, socket) do
    socket = ensure_membership(socket, session)

    current_user = socket.assigns[:current_user]
    role = membership_role(socket)

    authorized? = current_user && role in [:staff, :admin, :owner]

    if authorized? do
      {:cont, socket}
    else
      {:halt, Phoenix.LiveView.redirect(socket, to: ~p"/sign-in")}
    end
  end

  def on_mount(:live_admin_required, _params, session, socket) do
    socket = ensure_membership(socket, session)
    current_user = socket.assigns[:current_user]
    role = membership_role(socket)

    authorized? = current_user && role in [:admin, :owner]

    if authorized? do
      {:cont, socket}
    else
      {:halt, Phoenix.LiveView.redirect(socket, to: ~p"/sign-in")}
    end
  end

  def on_mount(:live_no_user, _params, _session, socket) do
    if socket.assigns[:current_user] do
      {:halt, Phoenix.LiveView.redirect(socket, to: ~p"/")}
    else
      {:cont, socket |> assign(:current_user, nil) |> assign(:current_membership, nil)}
    end
  end

  defp ensure_membership(socket, session) do
    if socket.assigns[:current_user] == nil do
      assign(socket, :current_membership, nil)
    else
      assign(socket, :current_membership, lookup_membership(socket, session))
    end
  end

  defp lookup_membership(socket, session) do
    with %{id: user_id} <- socket.assigns[:current_user],
         org_id when is_binary(org_id) <- session && session["organization_id"],
         {:ok, membership} <-
           Accounts.get_membership(org_id, user_id, tenant: org_id, authorize?: false),
         %{} = membership <- membership do
      membership
    else
      _ -> nil
    end
  end

  defp membership_role(%{assigns: %{current_membership: %{role: role}}}), do: role
  defp membership_role(%{assigns: %{current_user: %{role: role}}}), do: role
  defp membership_role(_socket), do: nil
end
