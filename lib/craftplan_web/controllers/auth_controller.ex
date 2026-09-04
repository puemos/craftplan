defmodule CraftplanWeb.AuthController do
  use CraftplanWeb, :controller
  use AshAuthentication.Phoenix.Controller

  alias AshAuthentication.Info
  alias AshAuthentication.Strategy.Password
  alias Craftplan.Accounts.User

  def success(conn, {:confirm_new_user, :confirm}, %{role: role} = user, _token) when role in [:staff, :admin] do
    password_strategy = Info.strategy!(User, :password)

    case Password.reset_token_for(password_strategy, user) do
      {:ok, reset_token} ->
        conn
        |> put_flash(:info, "Your email has been confirmed. Set a password to finish setup.")
        |> redirect(to: ~p"/password-reset/#{reset_token}")

      :error ->
        conn
        |> put_flash(:error, "Your email was confirmed, but password setup could not be started.")
        |> redirect(to: ~p"/reset")
    end
  end

  def success(conn, activity, user, _token) do
    return_to = get_session(conn, :return_to) || ~p"/manage/overview"

    message =
      case activity do
        {:confirm_new_user, :confirm} -> "Your email address has now been confirmed"
        {:password, :reset} -> "Your password has successfully been reset"
        _ -> "You are now signed in"
      end

    conn
    |> delete_session(:return_to)
    |> store_in_session(user)
    # If your resource has a different name, update the assign name here (i.e :current_admin)
    |> assign(:current_user, user)
    |> put_flash(:info, message)
    |> redirect(to: return_to)
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

        {{:password, :reset}, _reason} ->
          """
          Your password could not be changed. The link may be invalid or expired; request a new one and try again.
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
end
