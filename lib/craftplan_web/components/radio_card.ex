defmodule CraftplanWeb.Components.RadioCard do
  @moduledoc """
  The `CraftplanWeb.Components.RadioCard` module provides a customizable radio card component for Phoenix LiveView
  applications. This component extends beyond basic radio buttons by offering a card-based interface
  with rich styling options.

  ## Key Features
  - Multiple visual variants: base, default, outline, shadow, and bordered
  - Comprehensive color themes including natural, primary, secondary, etc.
  - Customizable borders, padding, and spacing
  - Support for icons and descriptions within cards
  - Grid layout options for organizing multiple cards
  - Built-in dark mode support
  - Accessible form integration

  ## Example Usage
  ```heex
  <.radio_card name="plan" class="w-full" icon="hero-home">
    <:radio value="basic" title="Basic Plan" description="For small teams">
    </:radio>
    <:radio value="pro" title="Pro Plan" description="For growing businesses">
    </:radio>
    <:radio value="pro">
      <p>$25/month</p>
    </:radio>
  </.radio_card>
  ```

  The component handles form integration automatically when used with Phoenix.HTML.Form fields
  and includes built-in error handling and validation display.

  """
  use Phoenix.Component

  import CraftplanWeb.Components.Icon, only: [icon: 1]

  alias Phoenix.HTML.Form
  alias Phoenix.HTML.FormField

  @doc type: :component
  attr :id, :string,
    default: nil,
    doc: "A unique identifier is used to manage state and interaction"

  attr :class, :string, default: nil, doc: "Custom CSS class for additional styling"
  attr :color, :string, default: "natural", doc: "Determines color theme"
  attr :variant, :string, default: "base", doc: "Determines variant theme"
  attr :border, :string, default: "extra_small", doc: "Determines border style"
  attr :rounded, :string, default: "medium", doc: "Radius size"
  attr :padding, :string, default: "small", doc: "Padding size"
  attr :space, :string, default: "small", doc: "Determines space between elements"
  attr :cols, :string, default: "one", doc: "Determines cols of elements"
  attr :cols_gap, :string, default: "small", doc: "Determines gap between elements"
  attr :label_class, :string, default: nil, doc: "Custom CSS class for the label styling"
  attr :reverse, :boolean, default: false, doc: "Switches the order of the element and label"
  attr :show_radio, :boolean, default: false, doc: "Boolean to show and hide radio"
  attr :label, :string, default: nil, doc: "Specifies text for the label"
  attr :description, :string, default: nil, doc: "Determines a short description"
  attr :wrapper_class, :string, default: nil, doc: "Custom CSS class for the wrapper"

  attr :field_label_wrapper, :string,
    default: nil,
    doc: "Custom CSS class for the field label wrapper"

  attr :description_class, :string,
    default: "text-[12px]",
    doc: "Custom CSS class for the description"

  attr :size, :string,
    default: "small",
    doc: "Determines the overall size of the elements, including padding, font size, and other items"

  attr :error_icon, :string, default: nil, doc: "Icon to be displayed alongside error messages"
  attr :errors, :list, default: [], doc: "List of error messages to be displayed"
  attr :name, :any, doc: "Name of input"
  attr :value, :any, doc: "Value of input"

  attr :rest, :global,
    include: ~w(autocomplete disabled form indeterminate multiple readonly required title autofocus),
    doc: "Global attributes can define defaults which are merged with attributes provided by the caller"

  attr :field, FormField, doc: "a form field struct retrieved from the form"

  slot :radio, required: true do
    attr :value, :string, required: true
    attr :checked, :boolean, required: false
    attr :icon, :string, doc: "Icon displayed alongside of a radio"
    attr :title, :string, required: false
    attr :icon_class, :string, doc: "Determines custom class for the icon"
    attr :radio_wrapper_class, :string, doc: "Custom CSS class for the wrapper of radio"
    attr :description_class, :string, doc: "Determines custom class for the description"
    attr :title_class, :string, doc: "Determines custom class for the title"
    attr :description, :string, required: false
    attr :card_label_class, :string, doc: "Custom CSS class for the wrapper of card label"
    attr :content_class, :string, doc: "Determines custom class for the content"
    attr :content_wrapper_class, :string, doc: "Determines custom class for the content wrapper"
    attr :radio_input_class, :string, doc: "Custom CSS class for styling the radio input"
  end

  slot :inner_block

  @spec radio_card(map()) :: Phoenix.LiveView.Rendered.t()
  def radio_card(%{field: %FormField{} = field} = assigns) do
    errors = if Phoenix.Component.used_input?(field), do: field.errors, else: []

    assigns
    |> assign(field: nil, id: assigns.id || field.id)
    |> assign(:errors, Enum.map(errors, &translate_error(&1)))
    |> assign_new(:name, fn -> field.name end)
    |> assign_new(:value, fn -> field.value end)
    |> radio_card()
  end

  def radio_card(assigns) do
    ~H"""
    <div class={["leading-5", space_class(@space), @class]} {@rest}>
      <input type="hidden" name={@name} value="" disabled={@rest[:disabled]} />

      <div :if={@label || @description} class={["radio-card-label-wrapper", @field_label_wrapper]}>
        <.label :if={@label} for={@id} class={@label_class}>{@label}</.label>
        <div :if={@description} class={@description_class}>
          {@description}
        </div>
      </div>

      <div
        class={["grid", grid_cols(@cols), grid_gap(@cols_gap), @wrapper_class]}
        role="radiogroup"
        aria-labelledby={@id && "#{@id}-label"}
        aria-describedby={@id && "#{@id}-desc"}
      >
        <label
          :for={{radio, index} <- Enum.with_index(@radio, 1)}
          for={"#{@id}-#{index}"}
          class={[
            "radio-card-wrapper flex cursor-pointer items-start",
            "has-[:disabled]:pointer-events-none has-[:disabled]:opacity-50",
            "has-[:focus-visible]:outline has-[:focus-visible]:outline-2 has-[:focus-visible]:outline-blue-400",
            "transition-all has-[:focus-visible]:outline-offset-[-2px]",
            @reverse && "flex-row-reverse",
            border_class(@border, @variant),
            color_variant(@variant, @color),
            rounded_size(@rounded),
            padding_size(@padding),
            size_class(@size),
            radio[:radio_wrapper_class]
          ]}
          {@rest}
        >
          <input
            type="radio"
            aria-checked={radio[:checked]}
            aria-labelledby={"#{@id}-#{index}-title"}
            aria-describedby={"#{@id}-#{index}-desc"}
            name={@name}
            id={"#{@id}-#{index}"}
            value={radio[:value]}
            checked={radio[:checked]}
            class={[
              "radio-card-input shrink-0 appearance-none focus:ring-0 focus:ring-offset-0",
              "disabled:opacity-50",
              !@show_radio && "absolute opacity-0",
              radio[:radio_input_class]
            ]}
          />
          <div
            data-part="label"
            class={["radio-card-content-wrapper flex-1", radio[:card_label_class]]}
          >
            <div
              :if={!is_nil(radio[:icon]) || radio[:title] || radio[:description]}
              class={["radio-slot-content", radio[:content_wrapper_class]]}
            >
              <.icon
                :if={!is_nil(radio[:icon])}
                name={radio[:icon]}
                class={["mx-auto block", radio[:icon_class]]}
              />
              <div
                :if={radio[:title]}
                class={["radio-card-title leading-[16px] block font-semibold", radio[:title_class]]}
              >
                {radio[:title]}
              </div>

              <p
                :if={radio[:description]}
                class={["radio-card-description", radio[:description_class]]}
              >
                {radio[:description]}
              </p>
            </div>
            <div
              :if={Map.get(radio, :inner_block)}
              class={["radio-card-content leading-[17px]", radio[:content_class]]}
            >
              {render_slot(radio)}
            </div>
          </div>
        </label>
      </div>
    </div>

    <.error :for={msg <- @errors} icon={@error_icon}>{msg}</.error>
    """
  end

  def radio_card_check(:list, {field, value}, %{params: params, data: data} = _form) do
    if params[Atom.to_string(field)] do
      new_value = if is_atom(value), do: Atom.to_string(value), else: value
      new_value == params[Atom.to_string(field)]
    else
      Map.get(data, field) == value
    end
  end

  def radio_card_check(:boolean, field, %{params: params, data: data} = _form) do
    if params[Atom.to_string(field)] do
      Form.normalize_value("radio", params[Atom.to_string(field)])
    else
      Map.get(data, field, false)
    end
  end

  attr :id, :string, default: nil, doc: "Unique identifier"
  attr :for, :string, default: nil, doc: "Specifies the form which is associated with"
  attr :class, :any, default: nil, doc: "Custom CSS class for additional styling"
  slot :inner_block, required: true, doc: "Inner block that renders HEEx content"

  defp label(assigns) do
    ~H"""
    <label for={@for} class={["font-semibold leading-4", @class]} id={@id}>
      {render_slot(@inner_block)}
    </label>
    """
  end

  attr :icon, :string, default: nil, doc: "Icon displayed alongside of an item"
  slot :inner_block, required: true, doc: "Inner block that renders HEEx content"

  defp error(assigns) do
    ~H"""
    <p class="text-[14px] mt-3 flex items-center gap-3 text-rose-700">
      <.icon :if={!is_nil(@icon)} name={@icon} class="shrink-0" /> {render_slot(@inner_block)}
    </p>
    """
  end

  defp border_class(_, variant) when variant in ["default", "shadow"], do: nil

  defp border_class("none", _), do: nil
  defp border_class("extra_small", _), do: "border"
  defp border_class("small", _), do: "border-2"
  defp border_class("medium", _), do: "border-[3px]"
  defp border_class("large", _), do: "border-4"
  defp border_class("extra_large", _), do: "border-[5px]"
  defp border_class(params, _) when is_binary(params), do: params

  defp rounded_size("extra_small"), do: "rounded-sm"

  defp rounded_size("small"), do: "rounded"

  defp rounded_size("medium"), do: "rounded-md"

  defp rounded_size("large"), do: "rounded-lg"

  defp rounded_size("extra_large"), do: "rounded-xl"

  defp rounded_size("none"), do: nil

  defp rounded_size(params) when is_binary(params), do: params

  defp padding_size("extra_small"), do: "py-1 px-2"

  defp padding_size("small"), do: "py-2 px-3"

  defp padding_size("medium"), do: "py-3 px-4"

  defp padding_size("large"), do: "py-4 px-5"

  defp padding_size("extra_large"), do: "py-5 px-6"

  defp padding_size(params) when is_binary(params), do: params

  defp grid_cols("one"), do: "grid-cols-1"
  defp grid_cols("two"), do: "grid-cols-2"
  defp grid_cols("three"), do: "grid-cols-2 md:grid-cols-3"
  defp grid_cols("four"), do: "grid-cols-2 md:grid-cols-4"
  defp grid_cols("five"), do: "grid-cols-2 md:grid-cols-5"
  defp grid_cols("six"), do: "grid-cols-2 md:grid-cols-6"
  defp grid_cols("seven"), do: "grid-cols-2 md:grid-cols-7"
  defp grid_cols("eight"), do: "grid-cols-2 md:grid-cols-8"
  defp grid_cols("nine"), do: "grid-cols-2 md:grid-cols-9"
  defp grid_cols("ten"), do: "grid-cols-2 md:grid-cols-10"
  defp grid_cols("eleven"), do: "grid-cols-2 md:grid-cols-11"
  defp grid_cols("twelve"), do: "grid-cols-2 md:grid-cols-12"
  defp grid_cols(params) when is_binary(params), do: params

  defp grid_gap("extra_small"), do: "gap-1"
  defp grid_gap("small"), do: "gap-2"
  defp grid_gap("medium"), do: "gap-3"
  defp grid_gap("large"), do: "gap-4"
  defp grid_gap("extra_large"), do: "gap-5"
  defp grid_gap(params) when is_binary(params), do: params

  defp size_class("extra_small") do
    [
      "text-[13px]",
      "[&_.radio-card-icon]:size-5",
      "[&_.radio-card-description]:text-[11px]"
    ]
  end

  defp size_class("small") do
    [
      "text-[14px]",
      "[&_.radio-card-icon]:size-6",
      "[&_.radio-card-description]:text-[12px]"
    ]
  end

  defp size_class("medium") do
    [
      "text-[15px]",
      "[&_.radio-card-icon]:size-7",
      "[&_.radio-card-description]:text-[13px]"
    ]
  end

  defp size_class("large") do
    [
      "text-[16px]",
      "[&_.radio-card-icon]:size-8",
      "[&_.radio-card-description]:text-[14px]"
    ]
  end

  defp size_class("extra_large") do
    [
      "text-[17px]",
      "[&_.radio-card-icon]:size-9",
      "[&_.radio-card-description]:text-[15px]"
    ]
  end

  defp size_class(params) when is_binary(params), do: params

  defp space_class("extra_small") do
    [
      "[&_.radio-card-label-wrapper]:space-y-1",
      "[&_.radio-card-label-wrapper]:mb-1",
      "[&_.radio-card-wrapper]:gap-1 [&_.radio-slot-content]:gap-1"
    ]
  end

  defp space_class("small") do
    [
      "[&_.radio-card-label-wrapper]:space-y-1.5",
      "[&_.radio-card-label-wrapper]:mb-2",
      "[&_.radio-card-wrapper]:gap-2 [&_.radio-slot-content]:gap-2"
    ]
  end

  defp space_class("medium") do
    [
      "[&_.radio-card-label-wrapper]:space-y-2",
      "[&_.radio-card-label-wrapper]:mb-3",
      "[&_.radio-card-wrapper]:gap-3 [&_.radio-slot-content]:gap-3"
    ]
  end

  defp space_class("large") do
    [
      "[&_.radio-card-label-wrapper]:space-y-2.5",
      "[&_.radio-card-label-wrapper]:mb-4",
      "[&_.radio-card-wrapper]:gap-4 [&_.radio-slot-content]:gap-4"
    ]
  end

  defp space_class("extra_large") do
    [
      "[&_.radio-card-label-wrapper]:space-y-3",
      "[&_.radio-card-label-wrapper]:mb-5",
      "[&_.radio-card-wrapper]:gap-5 [&_.radio-slot-content]:gap-5"
    ]
  end

  defp space_class("none"), do: nil

  defp space_class(params) when is_binary(params), do: params

  defp color_variant("base", _) do
    [
      "bg-white text-base-text-light border-base-border-light shadow-sm",
      "dark:bg-base-bg-dark dark:text-base-text-dark dark:border-base-border-dark",
      "[&_.radio-card-input]:checked:accent-base-text-light",
      "dark:[&_.radio-card-input]:checked:accent-base-disabled-text-dark",
      "[&_.radio-card-input]:border-base-border-light dark:[&_.radio-card-input]:border-base-border-dark",
      "[&_.radio-card-input:checked]:border-base-text-light dark:[&_.radio-card-input:checked]:border-base-border-dark",
      "has-[:checked]:bg-base-hover-light dark:has-[:checked]:bg-base-hover-dark",
      "has-[:checked]:border-base-text-light dark:has-[:checked]:border-base-disabled-text-dark",
      "[&_.radio-card-input:not(:checked)]:bg-white dark:[&_.radio-card-input:not(:checked)]:bg-checkbox-unchecked-dark"
    ]
  end

  defp color_variant("default", "white") do
    [
      "bg-white text-black",
      "[&_.radio-card-input]:checked:accent-black",
      "[&_.radio-card-input]:border-black",
      "has-[:checked]:bg-[var(--color-checkbox-white-checked)]"
    ]
  end

  defp color_variant("default", "dark") do
    [
      "bg-[var(--color-default-dark-bg)] text-white",
      "[&_.radio-card-input]:checked:accent-white",
      "[&_.radio-card-input]:border-white",
      "has-[:checked]:bg-[var(--color-checkbox-dark-checked)]"
    ]
  end

  defp color_variant("default", "natural") do
    [
      "bg-natural-light text-white dark:bg-natural-dark dark:text-black",
      "[&_.radio-card-input]:checked:accent-silver-light",
      "dark:[&_.radio-card-input]:checked:accent-silver-hover-dark",
      "[&_.radio-card-input]:border-base-border-light dark:[&_.radio-card-input]:border-base-border-dark",
      "has-[:checked]:bg-natural-hover-light dark:has-[:checked]:bg-natural-hover-dark"
    ]
  end

  defp color_variant("default", "primary") do
    [
      "bg-primary-light text-white dark:bg-primary-dark dark:text-black",
      "[&_.radio-card-input]:checked:accent-[var(--color-checkbox-primary-checked)]",
      "[&_.radio-card-input]:border-[var(--color-checkbox-primary-checked)]",
      "has-[:checked]:bg-primary-hover-dark dark:has-[:checked]:bg-primary-hover-light"
    ]
  end

  defp color_variant("default", "secondary") do
    [
      "bg-secondary-light text-white dark:bg-secondary-dark dark:text-black",
      "[&_.radio-card-input]:checked:accent-[var(--color-checkbox-secondary-checked)]",
      "[&_.radio-card-input]:border-[var(--color-checkbox-secondary-checked)]",
      "has-[:checked]:bg-secondary-hover-light dark:has-[:checked]:bg-secondary-hover-dark"
    ]
  end

  defp color_variant("default", "success") do
    [
      "bg-success-light text-white dark:bg-success-dark dark:text-black",
      "[&_.radio-card-input]:checked:accent-[var(--color-checkbox-success-checked)]",
      "[&_.radio-card-input]:border-[var(--color-checkbox-success-checked)]",
      "has-[:checked]:bg-success-hover-light dark:has-[:checked]:bg-success-hover-dark"
    ]
  end

  defp color_variant("default", "warning") do
    [
      "bg-warning-light text-white dark:bg-warning-dark dark:text-black",
      "[&_.radio-card-input]:checked:accent-[var(--color-checkbox-warning-checked)]",
      "[&_.radio-card-input]:border-[var(--color-checkbox-warning-checked)]",
      "has-[:checked]:bg-warning-hover-light dark:has-[:checked]:bg-warning-hover-dark"
    ]
  end

  defp color_variant("default", "danger") do
    [
      "bg-danger-light text-white dark:bg-danger-dark dark:text-black",
      "[&_.radio-card-input]:checked:accent-[var(--color-checkbox-danger-checked)]",
      "[&_.radio-card-input]:border-[var(--color-checkbox-danger-checked)]",
      "has-[:checked]:bg-danger-hover-light dark:has-[:checked]:bg-danger-hover-dark"
    ]
  end

  defp color_variant("default", "info") do
    [
      "bg-info-light text-white dark:bg-info-dark dark:text-black",
      "[&_.radio-card-input]:checked:accent-[var(--color-checkbox-info-checked)]",
      "[&_.radio-card-input]:border-[var(--color-checkbox-info-checked)]",
      "has-[:checked]:bg-info-hover-light dark:has-[:checked]:bg-info-hover-dark"
    ]
  end

  defp color_variant("default", "misc") do
    [
      "bg-misc-light text-white dark:bg-misc-dark dark:text-black",
      "[&_.radio-card-input]:checked:accent-[var(--color-checkbox-misc-checked)]",
      "[&_.radio-card-input]:border-[var(--color-checkbox-misc-checked)]",
      "has-[:checked]:bg-misc-hover-light dark:has-[:checked]:bg-misc-hover-dark"
    ]
  end

  defp color_variant("default", "dawn") do
    [
      "bg-dawn-light text-white dark:bg-dawn-dark dark:text-black",
      "[&_.radio-card-input]:checked:accent-[var(--color-checkbox-dawn-checked)]",
      "[&_.radio-card-input]:border-[var(--color-checkbox-dawn-checked)]",
      "has-[:checked]:bg-dawn-hover-light dark:has-[:checked]:bg-dawn-hover-dark"
    ]
  end

  defp color_variant("default", "silver") do
    [
      "bg-silver-light text-white dark:bg-silver-dark dark:text-black",
      "[&_.radio-card-input]:checked:accent-silver-dark",
      "[&_.radio-card-input]:border-silver-dark",
      "has-[:checked]:bg-silver-hover-light dark:has-[:checked]:bg-silver-hover-dark"
    ]
  end

  defp color_variant("outline", "natural") do
    [
      "text-natural-light border-natural-light dark:text-natural-dark dark:border-natural-dark",
      "[&_.radio-card-input]:checked:accent-natural-dark",
      "[&_.radio-card-input]:border-natural-dark",
      "dark:[&_.radio-card-input]:checked:accent-natural-light",
      "dark:[&_.radio-card-input]:border-natural-light",
      "has-[:checked]:border-black dark:has-[:checked]:border-white"
    ]
  end

  defp color_variant("outline", "primary") do
    [
      "text-primary-light border-primary-light dark:text-primary-dark dark:border-primary-dark",
      "[&_.radio-card-input]:checked:accent-primary-light",
      "[&_.radio-card-input]:border-primary-light",
      "dark:[&_.radio-card-input]:checked:accent-primary-dark",
      "dark:[&_.radio-card-input]:border-primary-dark",
      "has-[:checked]:border-primary-indicator-light dark:has-[:checked]:border-primary-indicator-dark"
    ]
  end

  defp color_variant("outline", "secondary") do
    [
      "text-secondary-light border-secondary-light dark:text-secondary-dark dark:border-secondary-dark",
      "[&_.radio-card-input]:checked:accent-secondary-light",
      "[&_.radio-card-input]:border-secondary-light",
      "dark:[&_.radio-card-input]:checked:accent-secondary-dark",
      "dark:[&_.radio-card-input]:border-secondary-dark",
      "has-[:checked]:border-secondary-indicator-light dark:has-[:checked]:border-secondary-indicator-dark"
    ]
  end

  defp color_variant("outline", "success") do
    [
      "text-success-light border-success-light dark:text-success-dark dark:border-success-dark",
      "[&_.radio-card-input]:checked:accent-success-light",
      "[&_.radio-card-input]:border-success-light",
      "dark:[&_.radio-card-input]:checked:accent-success-dark",
      "dark:[&_.radio-card-input]:border-success-dark",
      "has-[:checked]:border-success-indicator-alt-light dark:has-[:checked]:border-success-indicator-dark"
    ]
  end

  defp color_variant("outline", "warning") do
    [
      "text-warning-light border-warning-light dark:text-warning-dark dark:border-warning-dark",
      "[&_.radio-card-input]:checked:accent-warning-light",
      "[&_.radio-card-input]:border-warning-light",
      "dark:[&_.radio-card-input]:checked:accent-warning-dark",
      "dark:[&_.radio-card-input]:border-warning-dark",
      "has-[:checked]:border-warning-indicator-alt-light dark:has-[:checked]:border-warning-indicator-dark"
    ]
  end

  defp color_variant("outline", "danger") do
    [
      "text-danger-light border-danger-light dark:text-danger-dark dark:border-danger-dark",
      "[&_.radio-card-input]:checked:accent-danger-light",
      "[&_.radio-card-input]:border-danger-light",
      "dark:[&_.radio-card-input]:checked:accent-danger-dark",
      "dark:[&_.radio-card-input]:border-danger-dark",
      "has-[:checked]:border-danger-indicator-alt-light dark:has-[:checked]:border-danger-indicator-dark"
    ]
  end

  defp color_variant("outline", "info") do
    [
      "text-info-light border-info-light dark:text-info-dark dark:border-info-dark",
      "[&_.radio-card-input]:checked:accent-info-light",
      "[&_.radio-card-input]:border-info-light",
      "dark:[&_.radio-card-input]:checked:accent-info-dark",
      "dark:[&_.radio-card-input]:border-info-dark",
      "has-[:checked]:border-info-indicator-alt-light dark:has-[:checked]:border-info-indicator-dark"
    ]
  end

  defp color_variant("outline", "misc") do
    [
      "text-misc-light border-misc-light dark:text-misc-dark dark:border-misc-dark",
      "[&_.radio-card-input]:checked:accent-misc-light",
      "[&_.radio-card-input]:border-misc-light",
      "dark:[&_.radio-card-input]:checked:accent-misc-dark",
      "dark:[&_.radio-card-input]:border-misc-dark",
      "has-[:checked]:border-misc-indicator-alt-light dark:has-[:checked]:border-misc-indicator-dark"
    ]
  end

  defp color_variant("outline", "dawn") do
    [
      "text-dawn-light border-dawn-light dark:text-dawn-dark dark:border-dawn-dark",
      "[&_.radio-card-input]:checked:accent-dawn-light",
      "[&_.radio-card-input]:border-dawn-light",
      "dark:[&_.radio-card-input]:checked:accent-dawn-dark",
      "dark:[&_.radio-card-input]:border-dawn-dark",
      "has-[:checked]:border-dawn-indicator-alt-light dark:has-[:checked]:border-dawn-indicator-dark"
    ]
  end

  defp color_variant("outline", "silver") do
    [
      "text-silver-light border-silver-light dark:text-silver-dark dark:border-silver-dark",
      "[&_.radio-card-input]:checked:accent-silver-light",
      "[&_.radio-card-input]:border-silver-light",
      "dark:[&_.radio-card-input]:checked:accent-silver-dark",
      "dark:[&_.radio-card-input]:border-silver-dark",
      "has-[:checked]:border-silver-indicator-alt-light dark:has-[:checked]:border-silver-indicator-dark"
    ]
  end

  defp color_variant("shadow", "natural") do
    [
      "bg-natural-light text-white dark:bg-natural-dark dark:text-black",
      "shadow-[0px_4px_6px_-4px_var(--color-shadow-natural)] shadow-[0px_10px_15px_-3px_var(--color-shadow-natural)] dark:shadow-none",
      "[&_.radio-card-input]:checked:accent-silver-light",
      "dark:[&_.radio-card-input]:checked:accent-silver-hover-dark",
      "[&_.radio-card-input]:border-base-border-light dark:[&_.radio-card-input]:border-base-border-dark",
      "has-[:checked]:bg-natural-hover-light dark:has-[:checked]:bg-natural-hover-dark"
    ]
  end

  defp color_variant("shadow", "primary") do
    [
      "bg-primary-light text-white dark:bg-primary-dark dark:text-black",
      "shadow-[0px_4px_6px_-4px_var(--color-shadow-primary)] shadow-[0px_10px_15px_-3px_var(--color-shadow-primary)] dark:shadow-none",
      "[&_.radio-card-input]:checked:accent-[var(--color-checkbox-primary-checked)]",
      "[&_.radio-card-input]:border-[var(--color-checkbox-primary-checked)]",
      "has-[:checked]:bg-primary-hover-dark dark:has-[:checked]:bg-primary-hover-light"
    ]
  end

  defp color_variant("shadow", "secondary") do
    [
      "bg-secondary-light text-white dark:bg-secondary-dark dark:text-black",
      "shadow-[0px_4px_6px_-4px_var(--color-shadow-secondary)] shadow-[0px_10px_15px_-3px_var(--color-shadow-secondary)] dark:shadow-none",
      "[&_.radio-card-input]:checked:accent-[var(--color-checkbox-secondary-checked)]",
      "[&_.radio-card-input]:border-[var(--color-checkbox-secondary-checked)]",
      "has-[:checked]:bg-secondary-hover-light dark:has-[:checked]:bg-primary-hover-light"
    ]
  end

  defp color_variant("shadow", "success") do
    [
      "bg-success-light text-white dark:bg-success-dark dark:text-black",
      "shadow-[0px_4px_6px_-4px_var(--color-shadow-success)] shadow-[0px_10px_15px_-3px_var(--color-shadow-success)] dark:shadow-none",
      "[&_.radio-card-input]:checked:accent-[var(--color-checkbox-success-checked)]",
      "[&_.radio-card-input]:border-[var(--color-checkbox-success-checked)]",
      "has-[:checked]:bg-success-hover-light dark:has-[:checked]:bg-success-hover-dark"
    ]
  end

  defp color_variant("shadow", "warning") do
    [
      "bg-warning-light text-white dark:bg-warning-dark dark:text-black",
      "shadow-[0px_4px_6px_-4px_var(--color-shadow-warning)] shadow-[0px_10px_15px_-3px_var(--color-shadow-warning)] dark:shadow-none",
      "[&_.radio-card-input]:checked:accent-[var(--color-checkbox-warning-checked)]",
      "[&_.radio-card-input]:border-[var(--color-checkbox-warning-checked)]",
      "has-[:checked]:bg-warning-hover-light dark:has-[:checked]:bg-warning-hover-dark"
    ]
  end

  defp color_variant("shadow", "danger") do
    [
      "bg-danger-light text-white dark:bg-danger-dark dark:text-black",
      "shadow-[0px_4px_6px_-4px_var(--color-shadow-danger)] shadow-[0px_10px_15px_-3px_var(--color-shadow-danger)] dark:shadow-none",
      "[&_.radio-card-input]:checked:accent-[var(--color-checkbox-danger-checked)]",
      "[&_.radio-card-input]:border-[var(--color-checkbox-danger-checked)]",
      "has-[:checked]:bg-danger-hover-light dark:has-[:checked]:bg-danger-hover-dark"
    ]
  end

  defp color_variant("shadow", "info") do
    [
      "bg-info-light text-white dark:bg-info-dark dark:text-black",
      "shadow-[0px_4px_6px_-4px_var(--color-shadow-info)] shadow-[0px_10px_15px_-3px_var(--color-shadow-info)] dark:shadow-none",
      "[&_.radio-card-input]:checked:accent-[var(--color-checkbox-info-checked)]",
      "[&_.radio-card-input]:border-[var(--color-checkbox-info-checked)]",
      "has-[:checked]:bg-info-hover-light dark:has-[:checked]:bg-info-hover-dark"
    ]
  end

  defp color_variant("shadow", "misc") do
    [
      "bg-misc-dark text-white dark:bg-misc-dark dark:text-black",
      "shadow-[0px_4px_6px_-4px_var(--color-shadow-misc)] shadow-[0px_10px_15px_-3px_var(--color-shadow-misc)] dark:shadow-none",
      "[&_.radio-card-input]:checked:accent-[var(--color-checkbox-misc-checked)]",
      "[&_.radio-card-input]:border-[var(--color-checkbox-misc-checked)]",
      "has-[:checked]:bg-misc-hover-light dark:has-[:checked]:bg-misc-hover-dark"
    ]
  end

  defp color_variant("shadow", "dawn") do
    [
      "bg-dawn-light text-white dark:bg-dawn-dark dark:text-black",
      "shadow-[0px_4px_6px_-4px_var(--color-shadow-dawn)] shadow-[0px_10px_15px_-3px_var(--color-shadow-dawn)] dark:shadow-none",
      "[&_.radio-card-input]:checked:accent-[var(--color-checkbox-dawn-checked)]",
      "[&_.radio-card-input]:border-[var(--color-checkbox-dawn-checked)]",
      "has-[:checked]:bg-dawn-hover-light dark:has-[:checked]:bg-dawn-hover-dark"
    ]
  end

  defp color_variant("shadow", "silver") do
    [
      "bg-silver-light text-white dark:bg-silver-dark dark:text-black",
      "shadow-[0px_4px_6px_-4px_var(--color-shadow-silver)] shadow-[0px_10px_15px_-3px_var(--color-shadow-silver)] dark:shadow-none",
      "[&_.radio-card-input]:checked:accent-silver-dark",
      "[&_.radio-card-input]:border-silver-dark",
      "has-[:checked]:bg-silver-hover-light dark:has-[:checked]:bg-silver-hover-dark"
    ]
  end

  defp color_variant("bordered", "white") do
    [
      "bg-white text-black border-[var(--color-bordered-white-border)]",
      "[&_.radio-card-input]:checked:accent-black",
      "[&_.radio-card-input]:border-black",
      "has-[:checked]:bg-[var(--color-checkbox-white-checked)]"
    ]
  end

  defp color_variant("bordered", "dark") do
    [
      "bg-[var(--color-bordered-dark-bg)] text-white border-[var(--color-bordered-dark-border)]",
      "[&_.radio-card-input]:checked:accent-white",
      "[&_.radio-card-input]:border-white",
      "has-[:checked]:bg-[var(--color-checkbox-dark-checked)]"
    ]
  end

  defp color_variant("bordered", "natural") do
    [
      "text-natural-bordered-text-light border-natural-bordered-text-light bg-natural-bordered-bg-light",
      "dark:text-natural-bordered-text-dark dark:border-natural-bordered-text-dark dark:bg-natural-bordered-bg-dark",
      "[&_.radio-card-input]:checked:accent-black",
      "dark:[&_.radio-card-input]:checked:accent-white",
      "[&_.radio-card-input]:border-natural-bordered-text-light dark:[&_.radio-card-input]:border-natural-bordered-text-dark",
      "has-[:checked]:border-black dark:has-[:checked]:border-white",
      "has-[:checked]:bg-natural-hover-dark dark:has-[:checked]:bg-silver-light"
    ]
  end

  defp color_variant("bordered", "primary") do
    [
      "text-primary-bordered-text-light border-primary-bordered-text-light bg-primary-bordered-bg-light",
      "dark:text-primary-bordered-text-dark dark:border-primary-bordered-text-dark dark:bg-primary-bordered-bg-dark",
      "[&_.radio-card-input]:checked:accent-primary-bordered-text-light",
      "dark:[&_.radio-card-input]:checked:accent-primary-bordered-text-dark",
      "[&_.radio-card-input]:border-primary-bordered-text-light dark:[&_.radio-card-input]:border-primary-bordered-text-dark",
      "has-[:checked]:border-primary-indicator-light dark:has-[:checked]:border-primary-indicator-dark",
      "has-[:checked]:bg-[var(--color-primary-gradient-indicator-dark)] dark:has-[:checked]:bg-primary-indicator-light"
    ]
  end

  defp color_variant("bordered", "secondary") do
    [
      "text-secondary-bordered-text-light border-secondary-bordered-text-light bg-secondary-bordered-bg-light",
      "dark:text-secondary-bordered-text-dark dark:border-secondary-bordered-text-dark dark:bg-secondary-bordered-bg-dark",
      "[&_.radio-card-input]:checked:accent-secondary-bordered-text-light",
      "dark:[&_.radio-card-input]:checked:accent-secondary-bordered-text-dark",
      "[&_.radio-card-input]:border-secondary-bordered-text-light dark:[&_.radio-card-input]:border-secondary-bordered-text-dark",
      "has-[:checked]:border-secondary-indicator-light dark:has-[:checked]:border-secondary-indicator-dark",
      "has-[:checked]:bg-[var(--color-secondary-gradient-indicator-dark)] dark:has-[:checked]:bg-secondary-indicator-light"
    ]
  end

  defp color_variant("bordered", "success") do
    [
      "text-success-bordered-text-light border-success-bordered-text-light bg-success-bordered-bg-light",
      "dark:text-success-bordered-text-dark dark:border-success-bordered-text-dark dark:bg-success-bordered-bg-dark",
      "[&_.radio-card-input]:checked:accent-success-bordered-text-light",
      "dark:[&_.radio-card-input]:checked:accent-success-bordered-text-dark",
      "[&_.radio-card-input]:border-success-bordered-text-light dark:[&_.radio-card-input]:border-success-bordered-text-dark",
      "has-[:checked]:border-success-indicator-alt-light dark:has-[:checked]:border-success-indicator-dark",
      "has-[:checked]:bg-[var(--color-success-gradient-indicator-dark)] dark:has-[:checked]:bg-success-indicator-alt-light"
    ]
  end

  defp color_variant("bordered", "warning") do
    [
      "text-warning-bordered-text-light border-warning-bordered-text-light bg-warning-bordered-bg-light",
      "dark:text-warning-bordered-text-dark dark:border-warning-bordered-text-dark dark:bg-warning-bordered-bg-dark",
      "[&_.radio-card-input]:checked:accent-warning-bordered-text-light",
      "dark:[&_.radio-card-input]:checked:accent-warning-bordered-text-dark",
      "[&_.radio-card-input]:border-warning-bordered-text-light dark:[&_.radio-card-input]:border-warning-bordered-text-dark",
      "has-[:checked]:border-warning-indicator-alt-light dark:has-[:checked]:border-warning-indicator-dark",
      "has-[:checked]:bg-[var(--color-warning-gradient-indicator-dark)] dark:has-[:checked]:bg-warning-indicator-alt-light"
    ]
  end

  defp color_variant("bordered", "danger") do
    [
      "text-danger-bordered-text-light border-danger-bordered-text-light bg-danger-bordered-bg-light",
      "dark:text-danger-bordered-text-dark dark:border-danger-bordered-text-dark dark:bg-danger-bordered-bg-dark",
      "[&_.radio-card-input]:checked:accent-danger-bordered-text-light",
      "dark:[&_.radio-card-input]:checked:accent-danger-bordered-text-dark",
      "[&_.radio-card-input]:border-danger-bordered-text-light dark:[&_.radio-card-input]:border-danger-bordered-text-dark",
      "has-[:checked]:border-danger-indicator-alt-light dark:has-[:checked]:border-danger-indicator-dark",
      "has-[:checked]:bg-[var(--color-danger-gradient-indicator-dark)] dark:has-[:checked]:bg-danger-indicator-alt-light"
    ]
  end

  defp color_variant("bordered", "info") do
    [
      "text-info-bordered-text-light border-info-bordered-text-light bg-info-bordered-bg-light",
      "dark:text-info-hover-dark dark:border-info-hover-dark dark:bg-info-bordered-bg-dark",
      "[&_.radio-card-input]:checked:accent-info-bordered-text-light",
      "dark:[&_.radio-card-input]:checked:accent-info--bordered-text-dark",
      "[&_.radio-card-input]:border-info-bordered-text-light dark:[&_.radio-card-input]:border-info-bordered-text-dark",
      "has-[:checked]:border-info-indicator-alt-light dark:has-[:checked]:border-info-indicator-dark",
      "has-[:checked]:bg-[var(--color-info-gradient-indicator-dark)] dark:has-[:checked]:bg-info-indicator-alt-light"
    ]
  end

  defp color_variant("bordered", "misc") do
    [
      "text-misc-bordered-text-light border-misc-bordered-text-light bg-misc-bordered-bg-light",
      "dark:text-misc-bordered-text-dark dark:border-misc-bordered-text-dark dark:bg-misc-bordered-bg-dark",
      "[&_.radio-card-input]:checked:accent-misc-bordered-text-light",
      "dark:[&_.radio-card-input]:checked:accent-misc-bordered-text-dark",
      "[&_.radio-card-input]:border-misc-bordered-text-light dark:[&_.radio-card-input]:border-misc-bordered-text-dark",
      "has-[:checked]:border-misc-indicator-alt-light dark:has-[:checked]:border-misc-indicator-dark",
      "has-[:checked]:bg-[var(--color-misc-gradient-indicator-dark)] dark:has-[:checked]:bg-misc-indicator-alt-light"
    ]
  end

  defp color_variant("bordered", "dawn") do
    [
      "text-dawn-bordered-text-light border-dawn-bordered-text-light bg-dawn-bordered-bg-light",
      "dark:text-dawn-bordered-text-dark dark:border-dawn-bordered-text-dark dark:bg-dawn-bordered-bg-dark",
      "[&_.radio-card-input]:checked:accent-dawn-bordered-text-light",
      "dark:[&_.radio-card-input]:checked:accent-dawn-bordered-text-dark",
      "[&_.radio-card-input]:border-dawn-bordered-text-light dark:[&_.radio-card-input]:border-dawn-bordered-text-dark",
      "has-[:checked]:border-dawn-indicator-alt-light dark:has-[:checked]:border-dawn-indicator-dark",
      "has-[:checked]:bg-[var(--color-dawn-gradient-indicator-dark)] dark:has-[:checked]:bg-dawn-indicator-alt-light"
    ]
  end

  defp color_variant("bordered", "silver") do
    [
      "text-silver-bordered-text-light border-silver-bordered-text-light bg-silver-bordered-bg-light",
      "dark:text-silver-bordered-text-dark dark:border-silver-bordered-text-dark dark:bg-silver-bordered-bg-dark",
      "[&_.radio-card-input]:checked:accent-silver-bordered-text-light",
      "dark:[&_.radio-card-input]:checked:accent-silver-bordered-text-dark",
      "[&_.radio-card-input]:border-silver-bordered-text-light dark:[&_.radio-card-input]:border-silver-bordered-text-dark",
      "has-[:checked]:border-silver-indicator-alt-light dark:has-[:checked]:border-silver-indicator-dark",
      "has-[:checked]:bg-natural-hover-dark dark:has-[:checked]:bg-silver-indicator-alt-light"
    ]
  end

  defp color_variant(params, _) when is_binary(params), do: params

  defp translate_error({msg, opts}) do
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
      Gettext.dngettext(CraftplanWeb.Gettext, "errors", msg, msg, count, opts)
    else
      Gettext.dgettext(CraftplanWeb.Gettext, "errors", msg, opts)
    end
  end
end
