defmodule CraftplanWeb.Auth.Components.Password.SignInForm do
  @moduledoc """
  Customized sign in form that also collects an organization slug.
  """

  use AshAuthentication.Phoenix.Overrides.Overridable,
    root_class: "CSS class for the root `div` element.",
    label_class: "CSS class for the `h2` element.",
    form_class: "CSS class for the `form` element.",
    slot_class: "CSS class for the `div` surrounding the slot.",
    button_text: "Text for the submit button.",
    disable_button_text: "Text for the submit button when the request is happening."

  use AshAuthentication.Phoenix.Web, :live_component

  import AshAuthentication.Phoenix.Components.Helpers,
    only: [auth_path: 5, auth_path: 6, debug_form_errors: 1]

  import Phoenix.Naming, only: [humanize: 1]
  import Slug

  alias AshAuthentication.Info
  alias AshAuthentication.Phoenix.Components.Password
  alias AshAuthentication.Strategy
  alias AshPhoenix.Form
  alias Phoenix.LiveView.Rendered
  alias Phoenix.LiveView.Socket

  @type props :: %{
          required(:strategy) => Strategy.t(),
          optional(:label) => String.t() | false,
          optional(:current_tenant) => String.t(),
          optional(:context) => map(),
          optional(:auth_routes_prefix) => String.t(),
          optional(:overrides) => [module],
          optional(:gettext_fn) => {module, atom}
        }

  @doc false
  @impl true
  @spec update(props, Socket.t()) :: {:ok, Socket.t()}
  def update(assigns, socket) do
    strategy = assigns.strategy
    domain = Info.authentication_domain!(strategy.resource)
    subject_name = Info.authentication_subject_name!(strategy.resource)

    socket =
      socket
      |> assign(assigns)
      |> assign(trigger_action: false, subject_name: subject_name)
      |> assign_new(:label, fn -> humanize(strategy.sign_in_action_name) end)
      |> assign_new(:inner_block, fn -> nil end)
      |> assign_new(:overrides, fn -> [AshAuthentication.Phoenix.Overrides.Default] end)
      |> assign_new(:gettext_fn, fn -> nil end)
      |> assign_new(:current_tenant, fn -> nil end)
      |> assign_new(:context, fn -> %{} end)
      |> assign_new(:auth_routes_prefix, fn -> nil end)
      |> assign_new(:organization_slug, fn -> nil end)

    context =
      Ash.Helpers.deep_merge_maps(assigns[:context] || %{}, %{
        strategy: strategy,
        private: %{ash_authentication?: true}
      })

    context =
      if Map.get(socket.assigns.strategy, :sign_in_tokens_enabled?) do
        Map.put(context, :token_type, :sign_in)
      else
        context
      end

    form =
      Form.for_action(strategy.resource, strategy.sign_in_action_name,
        domain: domain,
        as: subject_name |> to_string() |> slugify(),
        id: slugify("#{subject_name}-#{Strategy.name(strategy)}-#{strategy.sign_in_action_name}"),
        tenant: assigns[:current_tenant],
        transform_errors: _transform_errors(),
        context: context
      )

    socket = assign(socket, form: form, trigger_action: false, subject_name: subject_name)

    {:ok, socket}
  end

  @doc false
  @impl true
  @spec render(Socket.assigns()) :: Rendered.t() | no_return
  def render(assigns) do
    ~H"""
    <div class={override_for(@overrides, :root_class)}>
      <%= if @label do %>
        <h2 class={override_for(@overrides, :label_class)}>{_gettext(@label)}</h2>
      <% end %>

      <.form
        :let={form}
        for={@form}
        id={@form.id}
        phx-change="change"
        phx-submit="submit"
        phx-trigger-action={@trigger_action}
        phx-target={@myself}
        action={auth_path(@socket, @subject_name, @auth_routes_prefix, @strategy, :sign_in)}
        method="POST"
        class={override_for(@overrides, :form_class)}
      >
        <Password.Input.identity_field
          strategy={@strategy}
          form={form}
          overrides={@overrides}
          gettext_fn={@gettext_fn}
        />
        <Password.Input.password_field
          strategy={@strategy}
          form={form}
          overrides={@overrides}
          gettext_fn={@gettext_fn}
        />

        <div class="mt-2 mb-2">
          <label
            class="mb-1 block text-sm font-medium text-stone-700 dark:text-stone-900"
            for={slug_field_id(form)}
          >
            Organization Slug
          </label>
          <input
            type="text"
            id={slug_field_id(form)}
            name={slug_field_name(form)}
            value={@organization_slug || ""}
            class="block w-full appearance-none rounded-md border border-stone-300 px-3 py-2 placeholder-stone-400 focus:ring-blue-pale-500 focus:border-blue-pale-500 focus:outline-none dark:text-black sm:text-sm"
            autocomplete="organization"
            required
          />
        </div>

        <div class="mt-2 text-sm text-stone-600">
          New to Craftplan?
          <a href="/register" class="font-semibold text-emerald-700 hover:text-emerald-800">
            Create an organization
          </a>
        </div>

        <%= if @inner_block do %>
          <div class={override_for(@overrides, :slot_class)}>
            {render_slot(@inner_block, form)}
          </div>
        <% end %>

        <Password.Input.submit
          strategy={@strategy}
          id={@form.id <> "-submit"}
          form={form}
          action={:sign_in}
          label={override_for(@overrides, :button_text)}
          disable_text={override_for(@overrides, :disable_button_text)}
          overrides={@overrides}
          gettext_fn={@gettext_fn}
        />
      </.form>
    </div>
    """
  end

  @doc false
  @impl true
  @spec handle_event(String.t(), %{required(String.t()) => String.t()}, Socket.t()) ::
          {:noreply, Socket.t()}
  def handle_event("change", params, socket) do
    {slug, params} = pop_slug(params, socket.assigns.strategy, socket.assigns.organization_slug)

    form = Form.validate(socket.assigns.form, params, errors: false)

    {:noreply, assign(socket, form: form, organization_slug: slug)}
  end

  def handle_event("submit", params, socket) do
    {slug, params} = pop_slug(params, socket.assigns.strategy, socket.assigns.organization_slug)
    socket = assign(socket, :organization_slug, slug)

    if Map.get(socket.assigns.strategy, :sign_in_tokens_enabled?) do
      case Form.submit(socket.assigns.form,
             params: params,
             read_one?: true
           ) do
        {:ok, user} ->
          validate_sign_in_token_path =
            auth_path(
              socket,
              socket.assigns.subject_name,
              socket.assigns.auth_routes_prefix,
              socket.assigns.strategy,
              :sign_in_with_token,
              token: user.__metadata__.token,
              organization_slug: slug
            )

          {:noreply, redirect(socket, to: validate_sign_in_token_path)}

        {:error, form} ->
          debug_form_errors(form)

          {:noreply, assign(socket, :form, Form.clear_value(form, socket.assigns.strategy.password_field))}
      end
    else
      form = Form.validate(socket.assigns.form, params)

      socket =
        socket
        |> assign(:form, form)
        |> assign(:trigger_action, form.valid?)

      {:noreply, socket}
    end
  end

  defp pop_slug(params, strategy, default_slug) do
    param_key =
      strategy.resource
      |> Info.authentication_subject_name!()
      |> to_string()
      |> slugify()

    case Map.get(params, param_key) do
      %{} = inner ->
        {Map.get(inner, "organization_slug", default_slug), Map.delete(inner, "organization_slug")}

      _ ->
        {default_slug, %{}}
    end
  end

  defp slug_field_name(form), do: "#{form.name}[organization_slug]"
  defp slug_field_id(form), do: "#{form.id}-organization-slug"
end
