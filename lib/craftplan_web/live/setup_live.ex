defmodule CraftplanWeb.SetupLive do
  @moduledoc false
  use CraftplanWeb, :live_view_blank

  alias Craftplan.Accounts.User

  require Ash.Query

  @impl true
  def mount(_params, _session, socket) do
    if admin_exists?() do
      {:ok,
       socket
       |> put_flash(:info, "Setup already complete.")
       |> redirect(to: ~p"/sign-in")}
    else
      form =
        AshPhoenix.Form.for_create(User, :register_with_password,
          as: "user",
          authorize?: false
        )

      {:ok,
       socket
       |> assign(:page_title, "Setup")
       |> assign(:form, to_form(form))}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="mx-auto flex min-h-screen items-center justify-center bg-stone-50 px-4">
      <div class="w-full max-w-md space-y-6">
        <div class="text-center">
          <h1 class="text-2xl font-bold text-stone-900">Welcome to Craftplan</h1>
          <p class="mt-2 text-sm text-stone-600">
            Create your admin account to get started.
          </p>
        </div>

        <div class="rounded-lg border border-stone-200 bg-white p-6 shadow-sm">
          <.simple_form
            for={@form}
            id="setup-form"
            phx-change="validate"
            phx-submit="setup"
          >
            <.input field={@form[:email]} type="email" label="Email" />
            <.input field={@form[:password]} type="password" label="Password" />
            <.input
              field={@form[:password_confirmation]}
              type="password"
              label="Confirm password"
            />

            <:actions>
              <.button variant={:primary} phx-disable-with="Creating account..." class="w-full">
                Create Admin Account
              </.button>
            </:actions>
          </.simple_form>
        </div>
      </div>
    </div>
    """
  end

  @impl true
  def handle_event("validate", %{"user" => user_params}, socket) do
    form = AshPhoenix.Form.validate(socket.assigns.form, user_params)
    {:noreply, assign(socket, form: to_form(form))}
  end

  def handle_event("setup", %{"user" => user_params}, socket) do
    if admin_exists?() do
      {:noreply,
       socket
       |> put_flash(:error, "Setup already complete.")
       |> redirect(to: ~p"/sign-in")}
    else
      user_params = Map.put(user_params, "role", "admin")

      case AshPhoenix.Form.submit(socket.assigns.form, params: user_params, authorize?: false) do
        {:ok, _user} ->
          {:noreply,
           socket
           |> put_flash(:info, "Admin account created. Please sign in.")
           |> redirect(to: ~p"/sign-in")}

        {:error, form} ->
          {:noreply, assign(socket, form: to_form(form))}
      end
    end
  end

  defp admin_exists? do
    User
    |> Ash.Query.filter(role: :admin)
    |> Ash.read!(authorize?: false)
    |> Enum.any?()
  end
end
