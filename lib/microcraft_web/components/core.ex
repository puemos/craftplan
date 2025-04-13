defmodule MicrocraftWeb.Components.Core do
  @moduledoc """
  Provides core UI components.

  At first glance, this module may seem daunting, but its goal is to provide
  core building blocks for your application, such as modals, tables, and
  forms. The components consist mostly of markup and are well-documented
  with doc strings and declarative assigns. You may customize and style
  them in any way you want, based on your application growth and needs.

  The default components use Tailwind CSS, a utility-first CSS framework.
  See the [Tailwind CSS documentation](https://tailwindcss.com) to learn
  how to customize them or feel free to swap in another framework altogether.

  Icons are provided by [heroicons](https://heroicons.com). See `icon/1` for usage.
  """
  use Phoenix.Component
  use Gettext, backend: Microcraft.Gettext

  import MicrocraftWeb.HtmlHelpers

  alias Phoenix.HTML.FormField
  alias Phoenix.LiveView.JS

  @doc """
  Renders a keyboard key element.

  ## Examples

      <.kbd>Ctrl</.kbd>
      <.kbd>⌘</.kbd>

  ## Attributes

    * `:class` - Additional CSS classes to apply to the `<kbd>` element.
    * `:rest` - Any additional HTML attributes.

  """
  attr :class, :string, default: nil
  attr :rest, :global
  slot :inner_block, required: true

  def kbd(assigns) do
    ~H"""
    <kbd
      class={[
        "inline-block whitespace-nowrap rounded border border-stone-400 bg-stone-100 text-stone-700",
        "px-1 py-0.5 text-xs leading-none",
        @class
      ]}
      {@rest}
    >
      {render_slot(@inner_block)}
    </kbd>
    """
  end

  @doc """
  Renders a modal.

  ## Examples

      <.modal id="confirm-modal">
        This is a modal.
      </.modal>

  JS commands may be passed to the `:on_cancel` to configure
  the closing/cancel event, for example:

      <.modal id="confirm" on_cancel={JS.navigate(~p"/posts")}>
        This is another modal.
      </.modal>

  """
  attr :id, :string, required: true
  attr :show, :boolean, default: false
  attr :on_cancel, JS, default: %JS{}
  slot :inner_block, required: true

  def modal(assigns) do
    ~H"""
    <div
      id={@id}
      phx-mounted={@show && show_modal(@id)}
      phx-remove={hide_modal(@id)}
      data-cancel={JS.exec(@on_cancel, "phx-remove")}
      class="relative z-50 hidden"
    >
      <div
        id={"#{@id}-bg"}
        class="bg-stone-50/90 fixed inset-0 transition-opacity"
        aria-hidden="true"
      />
      <div
        class="fixed inset-0 overflow-y-auto"
        aria-labelledby={"#{@id}-title"}
        aria-describedby={"#{@id}-description"}
        role="dialog"
        aria-modal="true"
        tabindex="0"
      >
        <div class="flex min-h-full items-center justify-center">
          <div class="w-full max-w-4xl p-4 sm:p-6 lg:py-8">
            <.focus_wrap
              id={"#{@id}-container"}
              phx-window-keydown={JS.exec("data-cancel", to: "##{@id}")}
              phx-key="escape"
              phx-click-away={JS.exec("data-cancel", to: "##{@id}")}
              class="shadow-stone-700/10 ring-stone-700/20 relative hidden rounded bg-white p-14 shadow-lg ring-1 transition"
            >
              <div class="absolute top-6 right-5">
                <button
                  phx-click={JS.exec("data-cancel", to: "##{@id}")}
                  type="button"
                  class="-m-3 flex-none p-3 opacity-60 hover:opacity-100"
                  aria-label={gettext("close")}
                >
                  <.icon name="hero-x-mark-solid" class="h-5 w-5" />
                </button>
              </div>
              <div id={"#{@id}-content"}>
                {render_slot(@inner_block)}
              </div>
            </.focus_wrap>
          </div>
        </div>
      </div>
    </div>
    """
  end

  @doc """
  Renders flash notices.

  ## Examples

      <.flash kind={:info} flash={@flash} />
      <.flash kind={:info} phx-mounted={show("#flash")}>Welcome Back!</.flash>
  """
  attr :id, :string, doc: "the optional id of flash container"
  attr :flash, :map, default: %{}, doc: "the map of flash messages to display"
  attr :title, :string, default: nil
  attr :kind, :atom, values: [:info, :error], doc: "used for styling and flash lookup"
  attr :rest, :global, doc: "the arbitrary HTML attributes to add to the flash container"

  slot :inner_block, doc: "the optional inner block that renders the flash message"

  def flash(assigns) do
    assigns = assign_new(assigns, :id, fn -> "flash-#{assigns.kind}" end)

    ~H"""
    <div
      :if={msg = render_slot(@inner_block) || Phoenix.Flash.get(@flash, @kind)}
      id={@id}
      phx-click={JS.push("lv:clear-flash", value: %{key: @kind}) |> hide("##{@id}")}
      role="alert"
      class={[
        "group fixed right-2 bottom-4 z-50 mr-2 w-80 rounded-md p-4 shadow-xl ring-1 sm:w-96",
        @kind == :info && "bg-white fill-stone-900 text-stone-900 ring-gray-200",
        @kind == :error && "bg-white text-stone-900 ring-gray-200"
      ]}
      {@rest}
    >
      <p :if={@title} class="flex items-center gap-1.5 text-sm font-semibold leading-6">
        <%!-- <.icon :if={@kind == :info} name="hero-information-circle-mini bg-blue-500" class="h-4 w-4" /> --%>
        <.icon :if={@kind == :error} name="hero-exclamation-circle-mini bg-rose-500" class="h-4 w-4" />
        {@title}
      </p>
      <p class="mt-0.5 text-xs leading-5 text-stone-600">{msg}</p>
      <button
        type="button"
        class="group absolute top-1 right-2 p-1 opacity-40 transition-all group-hover:opacity-100"
        aria-label={gettext("close")}
      >
        <.icon name="hero-x-mark-solid" class="h-4 w-4" />
      </button>
    </div>
    """
  end

  @doc """
  Shows the flash group with standard titles and content.

  ## Examples

      <.flash_group flash={@flash} />
  """
  attr :flash, :map, required: true, doc: "the map of flash messages"
  attr :id, :string, default: "flash-group", doc: "the optional id of flash container"

  def flash_group(assigns) do
    ~H"""
    <div id={@id}>
      <.flash kind={:info} title={gettext("Success!")} flash={@flash} />
      <.flash kind={:error} title={gettext("Error!")} flash={@flash} />
      <.flash
        id="client-error"
        kind={:error}
        title={gettext("We can't find the internet")}
        phx-disconnected={show(".phx-client-error #client-error")}
        phx-connected={hide("#client-error")}
        hidden
      >
        {gettext("Attempting to reconnect")}
        <.icon name="hero-arrow-path" class="ml-1 h-3 w-3 animate-spin" />
      </.flash>

      <.flash
        id="server-error"
        kind={:error}
        title={gettext("Something went wrong!")}
        phx-disconnected={show(".phx-server-error #server-error")}
        phx-connected={hide("#server-error")}
        hidden
      >
        {gettext("Hang in there while we get back on track")}
        <.icon name="hero-arrow-path" class="ml-1 h-3 w-3 animate-spin" />
      </.flash>
    </div>
    """
  end

  @doc """
  Renders a button.

  ## Examples

      <.button>Send!</.button>
      <.button phx-click="go" class="ml-2">Send!</.button>
      <.button expanding={true}>Full Width & Height Button!</.button>
      <.button size={:sm}>Small Button</button>
      <.button size={:lg}>Large Button</button>
      <.button variant={:danger}>Danger Button</button>
      <.button variant={:outline}>Outline Button</button>
  """
  attr :type, :string, default: nil
  attr :class, :string, default: nil
  # For full width/height
  attr :expanding, :boolean, default: false
  attr :size, :atom, default: :base, values: [:sm, :base, :lg]
  attr :variant, :atom, default: :default, values: [:default, :danger, :outline]
  attr :rest, :global, include: ~w(disabled form name value)

  slot :inner_block, required: true

  def button(assigns) do
    ~H"""
    <button
      type={@type}
      class={[
        button_base_classes(),
        button_focus_classes(),
        button_variant_classes(@variant),
        if(@expanding, do: "h-full w-full", else: button_size_classes(@size)),
        @class
      ]}
      {@rest}
    >
      {render_slot(@inner_block)}
    </button>
    """
  end

  defp button_variant_classes(:default),
    do: "bg-stone-200/50 border border-stone-300 shadow-xs hover:bg-stone-200 hover:text-gray-800"

  defp button_variant_classes(:danger), do: "bg-rose-50 text-rose-500 hover:bg-rose-100 border border-rose-300 shadow-xs"

  defp button_variant_classes(:outline),
    do: "bg-transparent text-stone-700 border border-stone-300 shadow-xs hover:bg-stone-100"

  defp button_size_classes(:sm), do: "h-7 px-3 py-1 text-xs"
  defp button_size_classes(:base), do: "h-9 px-4 py-2"
  defp button_size_classes(:lg), do: "h-11 px-5 py-3 text-base"

  defp button_base_classes,
    do: "cursor-pointer inline-flex items-center justify-center gap-2 whitespace-nowrap rounded-md text-sm font-medium"

  defp button_focus_classes,
    do:
      "focus-visible:outline-none focus-visible:ring-1 focus-visible:ring-stone-300 disabled:pointer-events-none disabled:opacity-50"

  # Main Tabs Container
  slot :tab, required: true do
    attr :label, :string, required: true
    attr :path, :string, required: true
    attr :selected?, :boolean, required: true
  end

  attr :id, :string, required: true
  attr :class, :string, default: nil

  def tabs(assigns) do
    ~H"""
    <div class={["relative", @class]}>
      <.tabs_nav>
        <:tab :for={tab <- @tab}>
          <.tab_link label={tab.label} path={tab.path} selected?={tab.selected?} />
        </:tab>
      </.tabs_nav>
      <.tabs_content>
        <div :for={tab <- @tab} :if={tab.selected?} class="relative w-full">
          {render_slot(tab)}
        </div>
      </.tabs_content>
    </div>
    """
  end

  attr :label, :string, required: true
  attr :path, :string, required: true
  attr :selected?, :boolean, required: true

  def tab_link(assigns) do
    ~H"""
    <.link
      patch={@path}
      role="tab"
      aria-selected={@selected?}
      class={[
        "inline-flex items-center justify-center whitespace-nowrap rounded-md px-3 py-1",
        "text-sm font-medium ring-offset-white transition-all",
        "focus-visible:ring-ring focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-offset-2",
        "disabled:pointer-events-none disabled:opacity-50",
        "border",
        not @selected? && "border-transparent",
        @selected? && "border-stone-300 bg-stone-50 shadow"
      ]}
    >
      {@label}
    </.link>
    """
  end

  # Navigation Component
  slot :tab, required: true

  def tabs_nav(assigns) do
    ~H"""
    <div
      role="tablist"
      aria-orientation="horizontal"
      class="bg-stone-200/50 inline-flex h-9 rounded-lg p-1"
    >
      {render_slot(@tab)}
    </div>
    """
  end

  # Content Container Component
  slot :inner_block, required: true

  def tabs_content(assigns) do
    ~H"""
    <div class="content border-gray-200/70 relative mt-2 flex w-full items-center justify-center rounded-md border bg-white p-5">
      {render_slot(@inner_block)}
    </div>
    """
  end

  @doc """
  Renders a navigation breadcrumb trail.

  ## Example

      <.breadcrumb>
        <:crumb label="Home" path="/" />
        <:crumb label="Projects" path="/projects" />
        <:crumb label="Current Project" path="/projects/123" current?={true} />
      </.breadcrumb>

  ## Slots

    * `:crumb` - Required. Multiple crumb items that make up the breadcrumb trail.
      * `:label` - Required. The text to display for this breadcrumb item.
      * `:path` - Required. The navigation path for this breadcrumb item.
      * `:current?` - Optional. Boolean indicating if this is the current page (default: false).

  ## Attributes

    * `:class` - Optional. Additional CSS classes to apply to the nav element.
    * `:separator` - Optional. The separator between breadcrumb items (default: "/").


  """
  # Slot for individual crumb items
  slot :crumb, required: true do
    attr :label, :string, required: true
    attr :path, :string, required: true
    attr :current?, :boolean
  end

  # Main component attributes
  attr :class, :string, default: nil
  attr :separator, :string, default: "/"

  def breadcrumb(assigns) do
    ~H"""
    <nav class={["flex justify-between", @class]}>
      <ol class="inline-flex items-center space-x-1 text-base font-semibold">
        <li :for={{crumb, index} <- Enum.with_index(@crumb)} class="flex items-center">
          <.link
            :if={!crumb.current?}
            navigate={crumb.path}
            class="py-1 text-neutral-500 hover:text-neutral-900"
          >
            {crumb.label}
          </.link>

          <span :if={crumb.current?} class="py-1 text-neutral-900">
            {crumb.label}
          </span>

          <span :if={index < length(@crumb) - 1} class="mx-2 text-neutral-400">
            {@separator}
          </span>
        </li>
      </ol>
    </nav>
    """
  end

  @doc """
  Renders a label.
  """
  attr :for, :string, default: nil
  slot :inner_block, required: true

  def label(assigns) do
    ~H"""
    <label for={@for} class="block text-sm font-semibold leading-6 text-stone-800">
      {render_slot(@inner_block)}
    </label>
    """
  end

  @doc """
  Generates a generic error message.
  """
  slot :inner_block, required: true

  def error(assigns) do
    ~H"""
    <p class="mt-3 flex gap-3 text-sm leading-6 text-rose-600">
      <.icon name="hero-exclamation-circle-mini" class="mt-0.5 h-5 w-5 flex-none" />
      {render_slot(@inner_block)}
    </p>
    """
  end

  @doc """
  Renders a header with title.
  """
  attr :class, :string, default: nil

  slot :inner_block, required: true
  slot :subtitle
  slot :actions

  def header(assigns) do
    ~H"""
    <header class={["min-h-10 mb-4 flex items-center justify-between gap-6", @class]}>
      <div>
        <h1 class="text-lg font-semibold leading-8 text-stone-800">
          {render_slot(@inner_block)}
        </h1>
        <p :if={@subtitle != []} class="mt-2 text-sm leading-6 text-stone-600">
          {render_slot(@subtitle)}
        </p>
      </div>
      <div class="flex-none">{render_slot(@actions)}</div>
    </header>
    """
  end

  @doc """
  Renders a badge with customizable text and conditionally applied color classes based on a keyword list.
  """
  attr :text, :string, required: true, doc: "The text to display inside the badge"

  attr :value, :any,
    required: false,
    default: :default,
    doc: "The value to use for color lookup, can be atom or string"

  attr :colors, :list, default: [], doc: "A keyword list of statuses to CSS classes"

  def badge(assigns) do
    key =
      if Map.has_key?(assigns, :value) and assigns.value != :default do
        value = assigns.value

        cond do
          is_atom(value) -> value
          is_binary(value) -> String.to_atom(value)
          true -> :default
        end
      else
        cond do
          is_atom(assigns.text) -> assigns.text
          is_binary(assigns.text) -> String.to_atom(assigns.text)
          true -> :default
        end
      end

    color_class = Keyword.get(assigns.colors, key, "bg-stone-100 text-stone-700 border-stone-300")
    assigns = assign(assigns, :color_class, color_class)

    ~H"""
    <span class={[
      "inline-flex whitespace-nowrap rounded-full border px-2 text-xs font-normal capitalize leading-5",
      @color_class
    ]}>
      {format_label(@text)}
    </span>
    """
  end

  @doc """
  Renders a back navigation link.

  ## Examples

      <.back navigate={~p"/posts"}>Back to posts</.back>
  """
  attr :navigate, :any, required: true
  slot :inner_block, required: true

  def back(assigns) do
    ~H"""
    <div class="mt-16">
      <.link
        navigate={@navigate}
        class="text-sm font-semibold leading-6 text-stone-900 hover:text-stone-700"
      >
        <.icon name="hero-arrow-left-solid" class="h-3 w-3" />
        {render_slot(@inner_block)}
      </.link>
    </div>
    """
  end

  @doc """
  Renders a [Heroicon](https://heroicons.com).

  Heroicons come in three styles – outline, solid, and mini.
  By default, the outline style is used, but solid and mini may
  be applied by using the `-solid` and `-mini` suffix.

  You can customize the size and colors of the icons by setting
  width, height, and background color classes.

  Icons are extracted from the `deps/heroicons` directory and bundled within
  your compiled app.css by the plugin in your `assets/tailwind.config.js`.

  ## Examples

      <.icon name="hero-x-mark-solid" />
      <.icon name="hero-arrow-path" class="ml-1 w-3 h-3 animate-spin" />
  """
  attr :name, :string, required: true
  attr :class, :string, default: nil

  def icon(%{name: "hero-" <> _} = assigns) do
    ~H"""
    <span class={[@name, @class]} />
    """
  end

  attr :id, :any, default: "timezone"
  attr :name, :any, default: "timezone"

  attr :field, FormField, doc: "a form field struct retrieved from the form, for example: @form[:email]"

  def timezone(assigns) do
    assigns =
      assigns
      |> assign(id: get_in(assigns, [:field, :id]) || assigns.id)
      |> assign(name: get_in(assigns, [:field, :name]) || assigns.name)

    ~H"""
    <input type="hidden" name={@name} id={@id} phx-update="ignore" phx-hook="TimezoneInput" />
    """
  end

  ## JS Commands

  def show(js \\ %JS{}, selector) do
    JS.show(js,
      to: selector,
      time: 300,
      transition:
        {"transition-all transform ease-out duration-300", "opacity-0 translate-y-4 sm:translate-y-0 sm:scale-95",
         "opacity-100 translate-y-0 sm:scale-100"}
    )
  end

  def hide(js \\ %JS{}, selector) do
    JS.hide(js,
      to: selector,
      time: 200,
      transition:
        {"transition-all transform ease-in duration-200", "opacity-100 translate-y-0 sm:scale-100",
         "opacity-0 translate-y-4 sm:translate-y-0 sm:scale-95"}
    )
  end

  def show_modal(js \\ %JS{}, id) when is_binary(id) do
    js
    |> JS.show(to: "##{id}")
    |> JS.show(
      to: "##{id}-bg",
      time: 300,
      transition: {"transition-all transform ease-out duration-300", "opacity-0", "opacity-100"}
    )
    |> show("##{id}-container")
    |> JS.add_class("overflow-hidden", to: "body")
    |> JS.focus_first(to: "##{id}-content")
  end

  def hide_modal(js \\ %JS{}, id) do
    js
    |> JS.hide(
      to: "##{id}-bg",
      transition: {"transition-all transform ease-in duration-200", "opacity-100", "opacity-0"}
    )
    |> hide("##{id}-container")
    |> JS.hide(to: "##{id}", transition: {"block", "block", "hidden"})
    |> JS.remove_class("overflow-hidden", to: "body")
    |> JS.pop_focus()
  end
end
