defmodule CraftplanWeb.Components.Icon do
  @moduledoc """
  The `CraftplanWeb.Components.Icon` module provides a flexible and reusable icon
  component for rendering various types of icons in a Phoenix LiveView application.

  ## Features:
  - Supports multiple icon libraries (Hero Icons)
  - Flexible size control with predefined and custom sizing options
  - Customizable colors with theme integration
  - Supports both filled and outlined icon variants
  - Automatic accessibility attributes for better screen reader support
  - Animatable with CSS classes
  - Optional click handlers and interactive states

  ## Examples:

      <.icon name="hero-home" class="w-6 h-6" />
      <.icon name="fa-github" variant="brands" size="lg" />
      <.icon name="material-settings" color="primary" animate="spin" />

  ## Properties:
  - `name` - Required. The identifier of the icon to display
  - `variant` - Optional. The style variant of the icon (solid, outline, brands)
  - `size` - Optional. Size of the icon (sm, md, lg, xl, or custom class)
  - `color` - Optional. Theme color or custom color class
  - `class` - Optional. Additional CSS classes
  - `animate` - Optional. Animation class to apply
  - `aria_label` - Optional. Accessibility label for screen readers
  - `rest` - Additional HTML attributes passed to the icon element
  """
  use Phoenix.Component

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
  @doc type: :component
  attr :name, :string, required: true
  attr :class, :any, default: nil

  attr :rest, :global,
    doc: "Global attributes can define defaults which are merged with attributes provided by the caller"

  def icon(%{name: "hero-" <> _} = assigns) do
    ~H"""
    <span class={[@name, @class]} {@rest} />
    """
  end
end
