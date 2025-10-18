defmodule CraftplanWeb.Components.Forms do
  @moduledoc false
  use Phoenix.Component
  use Gettext, backend: Craftplan.Gettext

  import CraftplanWeb.Components.Core
  import CraftplanWeb.Components.Utils
  # import CraftplanWeb.HtmlHelpers

  alias Phoenix.HTML.FormField
  alias Phoenix.LiveView.JS

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

  attr :badge_colors, :list,
    default: [],
    doc: "A keyword list of statuses to CSS classes for badge-select"

  attr :type, :string,
    default: "text",
    values: ~w(checkbox checkdrop checkgroup color date datetime-local email file month number password
               range search select tel text textarea time url week radiogroup badge-select hidden)

  attr :field, FormField, doc: "a form field struct retrieved from the form, for example: @form[:email]"

  attr :errors, :list, default: []
  attr :checked, :boolean, doc: "the checked flag for checkbox inputs"
  attr :prompt, :string, default: nil, doc: "the prompt for select inputs"
  attr :options, :list, doc: "the options to pass to Phoenix.HTML.Form.options_for_select/2"
  attr :multiple, :boolean, default: false, doc: "the multiple flag for select inputs"

  attr :rest, :global, include: ~w(accept autocomplete capture cols disabled form list max maxlength min minlength
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

  def input(%{type: "checkgroup", options: options} = assigns) when is_list(options) do
    assigns =
      assign_new(assigns, :list_value, fn ->
        if is_list(assigns[:value]), do: assigns[:value], else: []
      end)

    ~H"""
    <fieldset phx-feedback-for={@name} required={@rest[:required]} class="h-full text-sm">
      <.label :if={@label} for={@id}>
        {@label}
      </.label>

      <div class={[
        "mt-1 w-full cursor-default overflow-y-auto rounded-md text-left focus:outline-none focus:ring-1 sm:text-sm",
        @errors == [] && "border-stone-300 focus:border-stone-400",
        @errors != [] && "border-rose-400 focus:border-rose-400"
      ]}>
        <div class="grid grid-cols-1 items-baseline gap-1 text-sm sm:grid-cols-2 md:grid-cols-3 lg:grid-cols-4">
          <div :for={{label, value} <- @options} class="flex items-center">
            <label
              for={"#{@name}-#{value}"}
              class={[
                "w-full cursor-pointer rounded-md border border-stone-300 p-2 font-medium text-stone-700 transition-all has-[:checked]:bg-blue-200/50 has-[:checked]:border-blue-300 hover:bg-stone-200 hover:text-gray-800",
                if(value in @list_value, do: "bg-stone-200/50")
              ]}
            >
              <input
                type="checkbox"
                id={"#{@name}-#{value}"}
                name={@name}
                value={value}
                checked={value in @list_value}
                class="mr-2 h-4 w-4 rounded border-stone-300 text-blue-500 checked:border-blue-300 focus:ring-0"
              />
              {label}
            </label>
          </div>
          <input type="hidden" name={@name} value="" />
        </div>
      </div>
      <.error :for={msg <- @errors}>{msg}</.error>
    </fieldset>
    """
  end

  def input(%{type: "checkdrop", options: options} = assigns) when is_list(options) do
    assigns =
      assign_new(assigns, :list_value, fn ->
        if is_list(assigns[:value]), do: assigns[:value], else: []
      end)

    ~H"""
    <div
      phx-click-away={JS.hide(to: "##{@id}-dropdown")}
      class="relative"
      title={selected_labels(@options, @list_value, @rest[:placeholder])}
    >
      <fieldset
        phx-feedback-for={@name}
        required={@rest[:required]}
        class="relative"
        style="min-inline-size: auto"
      >
        <.label :if={@label} for={@id}>
          {@label}
        </.label>

        <button
          type="button"
          phx-click={
            JS.toggle(to: "##{@id}-dropdown")
            |> JS.toggle_class("rotate-180", to: "##{@id}-chevron")
          }
          class={[
            "relative mt-2 w-full cursor-default rounded-md bg-white py-1.5 pr-10 pl-3 text-left text-sm leading-6",
            "border focus:outline-none focus:ring-1 focus:ring-stone-400",
            @errors == [] && "border-stone-300",
            @errors != [] && "border-rose-400"
          ]}
        >
          <span class={[
            "block w-full overflow-hidden text-ellipsis whitespace-nowrap",
            if(Enum.empty?(@list_value), do: "text-gray-500")
          ]}>
            {selected_labels(@options, @list_value, @rest[:placeholder])}
          </span>

          <span class="pointer-events-none absolute inset-y-0 right-0 flex items-center pr-2">
            <svg
              class="h-5 w-5 transform text-gray-400 transition-transform duration-200"
              id={"#{@id}-chevron"}
              viewBox="0 0 20 20"
              fill="currentColor"
            >
              <path
                fill-rule="evenodd"
                d="M5.23 7.21a.75.75 0 011.06.02L10 11.168l3.71-3.938a.75.75 0 111.08 1.04l-4.25 4.5a.75.75 0 01-1.08 0l-4.25-4.5a.75.75 0 01.02-1.06z"
                clip-rule="evenodd"
              />
            </svg>
          </span>
        </button>

        <div
          id={"#{@id}-dropdown"}
          class={[
            "absolute z-10 mt-1 max-h-60 w-full overflow-auto rounded-md bg-white py-1",
            "text-base shadow-lg ring-1 ring-stone-300 ring-opacity-5 focus:outline-none sm:text-sm",
            "hidden transform transition-all duration-200 ease-out"
          ]}
        >
          <div class="w-full space-y-1 p-2">
            <label
              :for={{label, value} <- @options}
              class="relative flex w-full cursor-pointer select-none items-center rounded-md px-3 py-2 transition-colors duration-150 hover:bg-stone-100"
            >
              <input
                type="checkbox"
                id={"#{@name}-#{value}"}
                name={@name}
                value={value}
                checked={value in @list_value}
                class="h-4 w-4 flex-shrink-0 rounded border-stone-300 text-blue-600 focus:ring-blue-600"
              />
              <span class="ml-3 block truncate text-sm font-medium text-gray-700">
                {label}
              </span>
            </label>
          </div>
        </div>
      </fieldset>

      <.error :for={msg <- @errors}>{msg}</.error>
    </div>
    """
  end

  def input(%{type: "radiogroup"} = assigns) do
    ~H"""
    <div>
      <.label :if={@label} for={@id}>{@label}</.label>
      <div class={[
        "mt-1 w-full overflow-y-auto rounded-md bg-white text-left focus:outline-none focus:ring-1 sm:text-sm",
        @errors == [] && "border-stone-300 focus:border-stone-400",
        @errors != [] && "border-rose-400 focus:border-rose-400"
      ]}>
        <div
          role="radiogroup"
          class="grid grid-cols-1 items-baseline gap-1 text-sm sm:grid-cols-2 md:grid-cols-3 lg:grid-cols-4"
        >
          <div :for={{label, val} <- @options} class="flex items-center">
            <label
              for={"#{@name}-#{val}"}
              class={[
                "w-full cursor-pointer rounded-md border border-stone-300 p-2 font-medium text-stone-700 transition-all hover:bg-stone-200 hover:text-gray-800",
                if(to_string(val) == to_string(@value), do: "bg-stone-200/50")
              ]}
            >
              <input
                type="radio"
                id={"#{@name}-#{val}"}
                name={@name}
                value={to_string(val)}
                checked={to_string(val) == to_string(@value)}
                class="mr-1 mb-0.5 h-4 w-4 border-blue-300 text-blue-400 focus:ring-0"
              />
              {label}
            </label>
          </div>
        </div>
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
          "block w-full bg-white focus:ring-0 sm:text-sm",
          @flat != true && "mt-2 rounded-md border border-gray-300 bg-white focus:border-stone-400",
          @flat == true && "!rounded-none border-none bg-transparent p-0"
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

  def input(%{type: "badge-select"} = assigns) do
    assigns = assign_new(assigns, :badge_colors, fn -> [] end)
    # Generate a unique ID for the dropdown if one isn't provided
    dropdown_id = "#{assigns.id}-dropdown-#{:erlang.unique_integer([:positive])}"
    assigns = assign(assigns, :dropdown_id, dropdown_id)

    ~H"""
    <div>
      <.label for={@id}>{@label}</.label>

      <div phx-click-away={JS.hide(to: "##{@dropdown_id}")} class="relative">
        <select id={@id} name={@name} class="hidden" {@rest}>
          <option :if={@prompt} value="">{@prompt}</option>
          {Phoenix.HTML.Form.options_for_select(@options, @value)}
        </select>

        <button
          type="button"
          phx-click={JS.toggle(to: "##{@dropdown_id}")}
          class={[
            "relative w-full cursor-default cursor-pointer text-left text-sm leading-6",
            "focus:outline-none",
            @flat != true && "rounded-md border p-2 hover:bg-white",
            @flat != true && @errors == [] && "border-stone-300",
            @flat != true && @errors != [] && "border-rose-400"
          ]}
        >
          <div class="flex items-center justify-between">
            <.badge
              text={selected_label(@options, @value, @prompt)}
              value={@value}
              colors={@badge_colors}
            />
            <svg
              class="h-5 w-5 text-gray-400"
              viewBox="0 0 20 20"
              fill="currentColor"
              aria-hidden="true"
            >
              <path
                fill-rule="evenodd"
                d="M5.23 7.21a.75.75 0 011.06.02L10 11.168l3.71-3.938a.75.75 0 111.08 1.04l-4.25 4.5a.75.75 0 01-1.08 0l-4.25-4.5a.75.75 0 01.02-1.06z"
                clip-rule="evenodd"
              />
            </svg>
          </div>
        </button>

        <div
          id={@dropdown_id}
          class={[
            "absolute z-10 mt-1 max-h-60 w-full overflow-auto rounded-md bg-white",
            "text-base shadow-lg ring-1 ring-stone-200 focus:outline-none sm:text-sm",
            "hidden transform transition-all duration-200 ease-out"
          ]}
        >
          <div class="w-full p-1">
            <div class="px-2 py-1.5 text-xs font-medium text-stone-500">
              Select an option
            </div>
            <div :for={{label, val} <- @options} class="flex items-center">
              <label
                for={"#{@name}-#{val}-#{@dropdown_id}"}
                class={[
                  "relative flex w-full cursor-pointer select-none items-center rounded-md px-2 py-1.5",
                  "transition-colors duration-100 hover:bg-stone-100",
                  to_string(val) == to_string(@value) && "bg-stone-200"
                ]}
              >
                <.badge text={label} value={val} colors={@badge_colors} />
                <input
                  type="radio"
                  id={"#{@name}-#{val}-#{@dropdown_id}"}
                  name={@name}
                  value={val}
                  phx-click={JS.toggle(to: "##{@dropdown_id}")}
                  checked={to_string(val) == to_string(@value)}
                  class="hidden h-4 w-4 flex-shrink-0 rounded border-stone-300 text-blue-600 focus:ring-blue-600"
                />
              </label>
            </div>
          </div>
        </div>
      </div>

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
          "min-h-[6rem] mt-2 block w-full rounded-md text-stone-900 focus:ring-0 sm:text-sm",
          @flat != true && "mt-2 text-stone-900",
          @flat == true && "!rounded-none border-none bg-transparent p-0",
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
            @flat == true && "!rounded-none border-none bg-transparent p-0",
            @inline_label != nil && "rounded-s-md",
            @inline_label == nil && "rounded-md",
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
              "blockrounded-lg rounded-s-0 border-s-0 rounded-e-md mt-2 inline-flex items-center border border-stone-300 bg-stone-200 px-3 text-sm text-stone-900 text-stone-900 focus:ring-0 sm:text-sm",
            @flat == true && "ml-2 block border-none bg-transparent p-0 focus:ring-0"
          ]}
        >
          {@inline_label}
        </span>
      </div>
      <.error :for={msg <- @errors} :if={@flat != true}>{msg}</.error>
    </div>
    """
  end

  defp selected_label(options, selected_value, placeholder) do
    options
    |> Enum.find(fn {_label, value} -> to_string(value) == to_string(selected_value) end)
    |> case do
      nil -> placeholder || "Select option..."
      {label, _value} -> label
    end
  end

  defp selected_labels(options, selected_values, placeholder) do
    options
    |> Enum.filter(fn {_label, value} -> value in selected_values end)
    |> Enum.map(fn {label, _value} -> label end)
    |> case do
      [] -> placeholder || "Select options..."
      selected -> Enum.join(selected, ", ")
    end
  end
end
