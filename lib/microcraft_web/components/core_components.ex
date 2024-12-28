defmodule MicrocraftWeb.CoreComponents do
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
        "text-xs leading-none py-0.5 px-1",
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
          <div class="w-full max-w-3xl p-4 sm:p-6 lg:py-8">
            <.focus_wrap
              id={"#{@id}-container"}
              phx-window-keydown={JS.exec("data-cancel", to: "##{@id}")}
              phx-key="escape"
              phx-click-away={JS.exec("data-cancel", to: "##{@id}")}
              class="shadow-stone-700/10 ring-stone-700/10 relative hidden rounded bg-white p-14 shadow-lg ring-1 transition"
            >
              <div class="absolute top-6 right-5">
                <button
                  phx-click={JS.exec("data-cancel", to: "##{@id}")}
                  type="button"
                  class="-m-3 flex-none p-3 opacity-20 hover:opacity-40"
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
        "fixed bottom-4 right-2 mr-2 w-80 sm:w-96 z-50 rounded-md p-4 group ring-1 shadow-xl",
        @kind == :info && "bg-white text-stone-900 ring-gray-200 fill-stone-900",
        @kind == :error && "bg-white text-stone-900 ring-gray-200"
      ]}
      {@rest}
    >
      <p :if={@title} class="flex items-center gap-1.5 text-sm font-semibold leading-6">
        <%!-- <.icon :if={@kind == :info} name="hero-information-circle-mini bg-blue-500" class="h-4 w-4" /> --%>
        <.icon :if={@kind == :error} name="hero-exclamation-circle-mini bg-rose-500" class="h-4 w-4" />
        {@title}
      </p>
      <p class="mt-0.5 text-stone-600 text-xs leading-5">{msg}</p>
      <button
        type="button"
        class="opacity-40 group-hover:opacity-100 transition-all group absolute top-1 right-2 p-1"
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
  Renders a simple form.

  ## Examples

      <.simple_form for={@form} phx-change="validate" phx-submit="save">
        <.input field={@form[:email]} label="Email"/>
        <.input field={@form[:username]} label="Username" />
        <:actions>
          <.button>Save</.button>
        </:actions>
      </.simple_form>
  """
  attr :for, :any, required: true, doc: "the data structure for the form"
  attr :as, :any, default: nil, doc: "the server side parameter to collect all input under"

  attr :rest, :global,
    include: ~w(autocomplete name rel action enctype method novalidate target multipart),
    doc: "the arbitrary HTML attributes to apply to the form tag"

  slot :inner_block, required: true
  slot :actions, doc: "the slot for form actions, such as a submit button"

  def simple_form(assigns) do
    ~H"""
    <.form :let={f} for={@for} as={@as} {@rest}>
      <div class="space-y-8 bg-white">
        {render_slot(@inner_block, f)}
        <div :for={action <- @actions} class="mt-2 flex items-center justify-between gap-6">
          {render_slot(action, f)}
        </div>
      </div>
    </.form>
    """
  end

  @doc """
  Renders a statistics card with a title, value, and description.

  ## Examples

      <.stat_card
        title="Total Orders"
        value="123"
        description="All time orders"
      />

      <.stat_card
        title="Revenue"
        # value={Number.Currency.number_to_currency(@total_revenue)}
        description="Last 30 days"
      />

  ## Attributes

    * `title` - The title of the statistic (required)
    * `value` - The main value to display (required)
    * `description` - Additional context or explanation (required)

  The component is designed to be used in grids or flex layouts for dashboard-style interfaces.
  Values can be formatted numbers, currency amounts, or any other string representation.
  """
  attr :title, :string, required: true, doc: "The title of the statistic"
  attr :value, :any, required: true, doc: "The main value to display"
  attr :description, :string, required: true, doc: "Additional context for the statistic"

  def stat_card(assigns) do
    ~H"""
    <div class="p-6 bg-white rounded-lg shadow">
      <dt class="text-sm font-medium text-gray-500">{@title}</dt>
      <dd class="mt-1">
        <div class="text-3xl font-semibold text-gray-900">{@value}</div>
        <div class="text-sm text-gray-500">{@description}</div>
      </dd>
    </div>
    """
  end

  @doc """
  Renders a button.

  ## Examples

      <.button>Send!</.button>
      <.button phx-click="go" class="ml-2">Send!</.button>
      <.button expanding={true}>Full Width & Height Button!</.button>
  """
  attr :type, :string, default: nil
  attr :class, :string, default: nil
  # For full width/height
  attr :expanding, :boolean, default: false
  attr :rest, :global, include: ~w(disabled form name value)

  slot :inner_block, required: true

  def button(assigns) do
    ~H"""
    <button
      type={@type}
      class={[
        "inline-flex items-center justify-center gap-2 whitespace-nowrap rounded-md text-sm font-medium",
        "focus-visible:outline-none focus-visible:ring-1 focus-visible:ring-stone-300 disabled:pointer-events-none disabled:opacity-50",
        "border border-stone-300 bg-stone-200/50 shadow-sm hover:bg-stone-200 hover:text-gray-800",
        if(@expanding, do: "w-full h-full", else: "h-9 px-4 py-2"),
        @class
      ]}
      {@rest}
    >
      {render_slot(@inner_block)}
    </button>
    """
  end

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
        <:tab :for={tab <- @tab} label={tab.label} path={tab.path} selected?={tab.selected?} />
      </.tabs_nav>
      <.tabs_content>
        <div :for={tab <- @tab} :if={tab.selected?} class="relative w-full">
          {render_slot(tab)}
        </div>
      </.tabs_content>
    </div>
    """
  end

  # Navigation Component
  slot :tab, required: true do
    attr :label, :string, required: true
    attr :path, :string, required: true
    attr :selected?, :boolean, required: true
  end

  def tabs_nav(assigns) do
    ~H"""
    <div
      role="tablist"
      aria-orientation="horizontal"
      class="h-9 inline-flex rounded-lg bg-stone-200/50 p-1"
    >
      <%= for tab <- @tab do %>
        <.link
          patch={tab.path}
          role="tab"
          aria-selected={tab.selected?}
          class={[
            "inline-flex items-center justify-center whitespace-nowrap rounded-md px-3 py-1",
            "text-sm font-medium ring-offset-white transition-all",
            "focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring focus-visible:ring-offset-2",
            "disabled:pointer-events-none disabled:opacity-50",
            "border",
            not tab.selected? && "border-transparent",
            tab.selected? && "bg-stone-50 border-stone-300 shadow"
          ]}
        >
          {tab.label}
        </.link>
      <% end %>
    </div>
    """
  end

  # Content Container Component
  slot :inner_block, required: true

  def tabs_content(assigns) do
    ~H"""
    <div class="relative flex items-center justify-center w-full p-5 mt-2 border rounded-md content border-gray-200/70 bg-white">
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
      <ol class="inline-flex items-center space-x-1 font-semibold text-base">
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
  Renders an input with label and error messages.

  A `Phoenix.HTML.FormField` may be passed as argument,
  which is used to retrieve the input name, id, and values.
  Otherwise all attributes may be passed explicitly.

  ## Types

  This function accepts all HTML input types, considering that:

    * You may also set `type="select"` to render a `<select>` tag

    * `type="checkbox"` is used exclusively to render boolean values

    * For live file uploads, see `Phoenix.Component.live_file_input/1`

  See https://developer.mozilla.org/en-US/docs/Web/HTML/Element/input
  for more information. Unsupported types, such as hidden and radio,
  are best written directly in your templates.

  ## Examples

      <.input field={@form[:email]} type="email" />
      <.input name="my-input" errors={["oh no!"]} />
  """
  attr :id, :any, default: nil
  attr :name, :any
  attr :label, :string, default: nil
  attr :inline_label, :string, default: nil
  attr :value, :any
  attr :flat, :boolean, default: false

  attr :type, :string,
    default: "text",
    values: ~w(checkbox color date datetime-local email file month number password
               range search select tel text textarea time url week segmented hidden)

  attr :field, FormField,
    doc: "a form field struct retrieved from the form, for example: @form[:email]"

  attr :errors, :list, default: []
  attr :checked, :boolean, doc: "the checked flag for checkbox inputs"
  attr :prompt, :string, default: nil, doc: "the prompt for select inputs"
  attr :options, :list, doc: "the options to pass to Phoenix.HTML.Form.options_for_select/2"
  attr :multiple, :boolean, default: false, doc: "the multiple flag for select inputs"

  attr :rest, :global,
    include: ~w(accept autocomplete capture cols disabled form list max maxlength min minlength
                multiple pattern placeholder readonly required rows size step)

  def input(%{field: %FormField{} = field} = assigns) do
    errors = if Phoenix.Component.used_input?(field), do: field.errors, else: []

    assigns
    |> assign(field: nil, id: assigns.id || field.id)
    |> assign(:errors, Enum.map(errors, &translate_error(&1)))
    |> assign_new(:name, fn -> if assigns.multiple, do: field.name <> "[]", else: field.name end)
    |> assign_new(:value, fn -> field.value end)
    |> input()
  end

  def input(%{type: "checkbox"} = assigns) do
    assigns =
      assign_new(assigns, :checked, fn ->
        Phoenix.HTML.Form.normalize_value("checkbox", assigns[:value])
      end)

    ~H"""
    <div>
      <label class="flex items-center gap-4 text-sm leading-6 text-stone-600">
        <input type="hidden" name={@name} value="false" disabled={@rest[:disabled]} />
        <input
          type="checkbox"
          id={@id}
          name={@name}
          value="true"
          checked={@checked}
          class="rounded border-stone-300 text-stone-900 focus:ring-0"
          {@rest}
        />
        {@label}
      </label>
      <.error :for={msg <- @errors}>{msg}</.error>
    </div>
    """
  end

  def input(%{type: "segmented"} = assigns) do
    ~H"""
    <div class="">
      <.label :if={@label} for={@id}>{@label}</.label>
      <div role="radiogroup" class="h-9 inline-flex rounded-lg bg-stone-200/50 p-1 mt-2">
        <%= for {label, val} <- @options do %>
          <label class={[
            "inline-flex items-center justify-center whitespace-nowrap rounded-md px-3 py-1",
            "text-sm font-medium ring-offset-white transition-all",
            "focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring focus-visible:ring-offset-2",
            "disabled:pointer-events-none disabled:opacity-50",
            "border",
            @rest[:disalbed] == nil && "cursor-default",
            @rest[:disalbed] != nil && "cursor-pointer",
            to_string(val) != to_string(@value) && "border-transparent",
            to_string(val) == to_string(@value) && "bg-stone-50 border-stone-300 shadow"
          ]}>
            <input
              type="radio"
              name={@name}
              value={to_string(val)}
              checked={to_string(val) == to_string(@value)}
              class="sr-only"
            />
            <span>{label}</span>
          </label>
        <% end %>
      </div>
      <.error :for={msg <- @errors}>{msg}</.error>
    </div>
    """
  end

  def input(%{type: "select"} = assigns) do
    ~H"""
    <div>
      <.label for={@id}>{@label}</.label>
      <select
        id={@id}
        name={@name}
        class={[
          "block w-full focus:ring-0 sm:text-sm",
          @flat != true && "mt-2 rounded-md border border-gray-300 bg-white focus:border-stone-400",
          @flat == true && "border-none bg-transparent p-0 !rounded-none"
        ]}
        multiple={@multiple}
        {@rest}
      >
        <option :if={@prompt} value="">{@prompt}</option>
        {Phoenix.HTML.Form.options_for_select(@options, @value)}
      </select>
      <.error :for={msg <- @errors}>{msg}</.error>
    </div>
    """
  end

  def input(%{type: "textarea"} = assigns) do
    ~H"""
    <div>
      <.label for={@id}>{@label}</.label>
      <textarea
        id={@id}
        name={@name}
        class={[
          @rest[:class] || "",
          "mt-2 block w-full rounded-lg text-stone-900 focus:ring-0 sm:text-sm min-h-[6rem]",
          @flat != true && "mt-2 text-stone-900",
          @flat == true && "border-none bg-transparent p-0 !rounded-none",
          @errors == [] && "border-stone-300 focus:border-stone-400",
          @errors != [] && "border-rose-400 focus:border-rose-400",
          @errors != [] && @flat == true && "text-rose-400"
        ]}
        {@rest}
      ><%= Phoenix.HTML.Form.normalize_value("textarea", @value) %></textarea>
      <.error :for={msg <- @errors}>{msg}</.error>
    </div>
    """
  end

  # All other inputs text, datetime-local, url, password, etc. are handled here...
  def input(assigns) do
    ~H"""
    <div>
      <.label for={@id}>{@label}</.label>
      <div class="flex">
        <input
          type={@type}
          name={@name}
          id={@id}
          value={Phoenix.HTML.Form.normalize_value(@type, @value)}
          class={[
            "block w-full focus:ring-0 sm:text-sm",
            @flat != true && "mt-2 text-stone-900",
            @flat == true && "border-none bg-transparent p-0 !rounded-none",
            @inline_label != nil && "rounded-s-lg",
            @inline_label == nil && "rounded-lg",
            @errors == [] && @flat != true && "border-stone-300 focus:border-stone-400",
            @errors != [] && @flat != true && "border-rose-400 focus:border-rose-400",
            @errors != [] && @flat == true && "text-rose-400"
          ]}
          {@rest}
        />
        <span
          :if={@inline_label != nil}
          class={[
            @flat != true &&
              "inline-flex mt-2 blockrounded-lg text-stone-900 focus:ring-0 sm:text-sm items-center px-3 text-sm text-stone-900 bg-stone-200 border rounded-s-0 border-stone-300 border-s-0 rounded-e-md",
            @flat == true && "ml-2 border-none bg-transparent p-0 block focus:ring-0"
          ]}
        >
          {@inline_label}
        </span>
      </div>
      <.error :for={msg <- @errors} :if={@flat != true}>{msg}</.error>
    </div>
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
    <header class={["flex items-center justify-between gap-6 mb-4", @class]}>
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
  attr :colors, :list, default: [], doc: "A keyword list of statuses to CSS classes"

  def badge(assigns) do
    key = if is_atom(assigns.text), do: assigns.text, else: :default
    color_class = Keyword.get(assigns.colors, key, "bg-stone-100 text-stone-700")

    assigns = assign(assigns, :color_class, color_class)

    ~H"""
    <span class={[
      "px-2 inline-flex text-xs leading-5 font-normal rounded-full capitalize border border-stone-300",
      @color_class
    ]}>
      {format_label(@text)}
    </span>
    """
  end

  @doc ~S"""
  Renders a table with generic styling.

  ## Examples

      <.table id="users" rows={@users}>
        <:col :let={user} label="id"><%= user.id %></:col>
        <:col :let={user} label="username"><%= user.username %></:col>
      </.table>
  """
  attr :id, :string, required: true
  attr :rows, :list, required: true
  attr :row_id, :any, default: nil, doc: "the function for generating the row id"
  attr :row_click, :any, default: nil, doc: "the function for handling phx-click on each row"

  attr :row_item, :any,
    default: &Function.identity/1,
    doc: "the function for mapping each row before calling the :col and :action slots"

  slot :col, required: true do
    attr :label, :string
  end

  slot :empty

  slot :action, doc: "the slot for showing user actions in the last table column"

  def table(assigns) do
    assigns =
      with %{rows: %Phoenix.LiveView.LiveStream{}} <- assigns do
        assign(assigns, row_id: assigns.row_id || fn {id, _item} -> id end)
      end

    ~H"""
    <div class="overflow-y-auto px-4 sm:overflow-visible sm:px-0">
      <table class="w-[40rem] mt-11 sm:w-full border-collapse">
        <thead class="text-sm text-left leading-6 text-stone-500 border-b border-stone-300">
          <tr>
            <th
              :for={{col, i} <- Enum.with_index(@col)}
              class={
                [
                  "p-0 pb-4 pr-6 font-normal border-r border-stone-200 last:border-r-0",
                  # Add padding-left for all header columns after the first
                  i > 0 && "pl-4"
                ]
              }
            >
              {col[:label]}
            </th>
            <th
              :if={@action != []}
              class="relative p-0 pb-4 pr-4 border-r border-stone-200 last:border-r-0"
            >
              <span class="sr-only">{gettext("Actions")}</span>
            </th>
          </tr>
        </thead>
        <tbody
          id={@id}
          phx-update={match?(%Phoenix.LiveView.LiveStream{}, @rows) && "stream"}
          class="relative divide-y divide-stone-200 text-sm leading-6 text-stone-700"
        >
          <tr :if={@empty != nil} id={"empty-#{@id}"} class="only:block hidden">
            <td colspan={Enum.count(@col)}>
              {render_slot(@empty)}
            </td>
          </tr>
          <tr :for={row <- @rows} id={@row_id && @row_id.(row)} class="group hover:bg-stone-200/40">
            <td
              :for={{col, i} <- Enum.with_index(@col)}
              phx-click={@row_click && @row_click.(row)}
              class={
                [
                  "relative p-0 border-r border-stone-200 border-b last:border-r-0",
                  # Add padding-left for all columns after the first
                  i > 0 && "pl-4",
                  @row_click && "hover:cursor-pointer"
                ]
              }
            >
              <div class="block py-4 pr-6">
                <span class={["relative"]}>
                  {render_slot(col, @row_item.(row))}
                </span>
              </div>
            </td>
            <td
              :if={@action != []}
              class="relative w-14 p-0 pr-4 border-r border-stone-200 border-b last:border-r-0"
            >
              <div class="relative whitespace-nowrap py-4 text-right text-sm font-medium">
                <span
                  :for={action <- @action}
                  class="relative ml-4 font-semibold leading-6 text-stone-900 hover:text-stone-700"
                >
                  {render_slot(action, @row_item.(row))}
                </span>
              </div>
            </td>
          </tr>
        </tbody>
      </table>
    </div>
    """
  end

  @doc """
  Renders a data list.

  ## Examples

      <.list>
        <:item title="Title"><%= @post.title %></:item>
        <:item title="Views"><%= @post.views %></:item>
      </.list>
  """
  slot :item, required: true do
    attr :title, :string, required: true
  end

  def list(assigns) do
    ~H"""
    <div class="">
      <dl class="-my-4 divide-y divide-stone-100">
        <div :for={item <- @item} class="flex gap-4 py-4 text-sm leading-6 sm:gap-8">
          <dt class="w-1/4 flex-none text-stone-500">{item.title}</dt>
          <dd class="text-stone-700">{render_slot(item)}</dd>
        </div>
      </dl>
    </div>
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

  attr :field, Phoenix.HTML.FormField,
    doc: "a form field struct retrieved from the form, for example: @form[:email]"

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
        {"transition-all transform ease-out duration-300",
         "opacity-0 translate-y-4 sm:translate-y-0 sm:scale-95",
         "opacity-100 translate-y-0 sm:scale-100"}
    )
  end

  def hide(js \\ %JS{}, selector) do
    JS.hide(js,
      to: selector,
      time: 200,
      transition:
        {"transition-all transform ease-in duration-200",
         "opacity-100 translate-y-0 sm:scale-100",
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

  @doc """
  Translates an error message using gettext.
  """
  def translate_error({msg, opts}) do
    # When using gettext, we typically pass the strings we want
    # to translate as a static argument:
    #
    #     # Translate the number of files with plural rules
    #     dngettext("errors", "1 file", "%{count} files", count)
    #
    # However the error messages in our forms and APIs are generated
    # dynamically, so we need to translate them by calling Gettext
    # with our gettext backend as first argument. Translations are
    # available in the errors.po file (as we use the "errors" domain).
    if count = opts[:count] do
      Gettext.dngettext(Microcraft.Gettext, "errors", msg, msg, count, opts)
    else
      Gettext.dgettext(Microcraft.Gettext, "errors", msg, opts)
    end
  end

  @doc """
  Translates the errors for a field from a keyword list of errors.
  """
  def translate_errors(errors, field) when is_list(errors) do
    for {^field, {msg, opts}} <- errors, do: translate_error({msg, opts})
  end
end
