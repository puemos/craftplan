defmodule CraftplanWeb.Auth.SignupLive do
  @moduledoc false
  use CraftplanWeb, :live_view

  alias Craftplan.Accounts.Signup
  alias CraftplanWeb.Auth.SignupForm
  alias CraftplanWeb.Components.Forms
  alias CraftplanWeb.Components.Utils
  alias Ecto.Changeset

  @impl true
  def mount(_params, _session, socket) do
    changeset = SignupForm.changeset(%SignupForm{}, %{})

    socket =
      socket
      |> assign(:form, to_form(changeset))
      |> assign(:page_title, "Create your Craftplan organization")

    {:ok, socket}
  end

  @impl true
  def handle_event("validate", %{"signup" => params}, socket) do
    changeset =
      %SignupForm{}
      |> SignupForm.changeset(params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :form, to_form(changeset))}
  end

  def handle_event("save", %{"signup" => params}, socket) do
    case SignupForm.apply(params) do
      {:ok, attrs} ->
        do_signup(socket, Map.from_struct(attrs), params)

      {:error, changeset} ->
        {:noreply, assign(socket, :form, to_form(changeset))}
    end
  end

  defp do_signup(socket, attrs, params) do
    case Signup.signup(attrs) do
      {:ok, %{organization: organization, token: token}} ->
        redirect_path =
          ~p"/auth/user/password/sign_in_with_token?#{[token: token, organization_slug: organization.slug]}"

        {:noreply,
         socket
         |> put_flash(:info, "Welcome to Craftplan! We're signing you in now.")
         |> redirect(to: redirect_path)}

      {:error, reason} ->
        changeset =
          %SignupForm{}
          |> SignupForm.changeset(params)
          |> Changeset.add_error(:base, format_error(reason))
          |> Map.put(:action, :validate)

        {:noreply, assign(socket, :form, to_form(changeset))}
    end
  end

  defp format_error({:missing_fields, fields}) do
    "Missing required fields: " <> Enum.map_join(fields, ", ", &humanize_field/1)
  end

  defp format_error(%Changeset{} = changeset) do
    changeset
    |> Changeset.traverse_errors(fn {msg, opts} ->
      Utils.translate_error({msg, opts})
    end)
    |> Enum.map_join(". ", fn {field, messages} ->
      "#{humanize_field(field)} #{Enum.join(messages, ", ")}"
    end)
  end

  defp format_error(reason), do: "Something went wrong: #{inspect(reason)}"

  defp humanize_field(field) do
    field
    |> Atom.to_string()
    |> String.replace("_", " ")
    |> String.capitalize()
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-stone-50 py-12">
      <div class="mx-auto w-full max-w-2xl rounded-lg bg-white p-10 shadow">
        <h1 class="mb-6 text-2xl font-semibold text-stone-800">Create your Craftplan organization</h1>
        <Forms.simple_form for={@form} phx-submit="save" phx-change="validate" as={:signup}>
          <div class="grid grid-cols-1 gap-6">
            <Forms.input
              field={@form[:organization_name]}
              label="Organization name"
              placeholder="Acme Bakery"
              required
            />

            <Forms.input
              field={@form[:organization_slug]}
              label="Organization slug"
              placeholder="acme-bakery"
            />

            <Forms.input
              field={@form[:admin_email]}
              label="Admin email"
              type="email"
              autocomplete="email"
              required
            />

            <Forms.input
              field={@form[:admin_password]}
              label="Password"
              type="password"
              autocomplete="new-password"
              required
            />

            <Forms.input
              field={@form[:admin_password_confirmation]}
              label="Confirm password"
              type="password"
              autocomplete="new-password"
              required
            />
          </div>

          <:actions>
            <div class="flex w-full justify-end">
              <button
                type="submit"
                class="inline-flex items-center justify-center rounded-md bg-emerald-600 px-4 py-2 text-sm font-semibold text-white shadow-sm hover:bg-emerald-700 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-emerald-600"
              >
                Start Craftplan
              </button>
            </div>
          </:actions>
        </Forms.simple_form>
      </div>
    </div>
    """
  end
end
