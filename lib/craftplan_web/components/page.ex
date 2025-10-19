defmodule CraftplanWeb.Components.Page do
  @moduledoc """
  Layout primitives that mirror the settings experience across manage views.

  These helpers encapsulate the common white-surface treatment, spacing, and
  responsive behavior used throughout Craftplan.
  """
  use Phoenix.Component

  alias Phoenix.LiveView.JS

  slot :inner_block, required: true
  attr :class, :string, default: nil

  def page(assigns) do
    ~H"""
    <div class={["space-y-6", @class]}>
      {render_slot(@inner_block)}
    </div>
    """
  end

  slot :inner_block, required: true
  slot :actions
  attr :title, :string, default: nil
  attr :description, :string, default: nil
  attr :class, :string, default: nil

  def section(assigns) do
    ~H"""
    <section class={["space-y-4", @class]}>
      <header
        :if={@title || @description || @actions != []}
        class="flex flex-col gap-3 sm:flex-row sm:items-start sm:justify-between"
      >
        <div class="space-y-1">
          <h2 :if={@title} class="text-base font-semibold text-stone-900 sm:text-lg">
            {@title}
          </h2>
          <p :if={@description} class="text-sm text-stone-500">
            {@description}
          </p>
        </div>

        <div
          :if={@actions != []}
          class="flex w-full items-center justify-start gap-2 sm:w-auto sm:justify-end"
        >
          {render_slot(@actions)}
        </div>
      </header>

      <div>
        {render_slot(@inner_block)}
      </div>
    </section>
    """
  end

  slot :inner_block, required: true
  slot :header
  slot :actions
  slot :footer
  attr :class, :string, default: nil
  attr :padding, :string, default: "p-6"
  attr :full_bleed, :boolean, default: false

  def surface(assigns) do
    assigns =
      assign(
        assigns,
        :content_classes,
        Enum.reject(["flex flex-col gap-4", assigns[:padding]], &is_nil/1)
      )

    ~H"""
    <div class={["rounded-md border border-gray-200 bg-white", @class]}>
      <div class={@content_classes}>
        <div
          :if={@header != [] || @actions != []}
          class="flex flex-col gap-3 sm:flex-row sm:items-start sm:justify-between"
        >
          <div>{render_slot(@header)}</div>
          <div :if={@actions != []} class="flex items-center gap-2">
            {render_slot(@actions)}
          </div>
        </div>

        <div>
          {render_slot(@inner_block)}
        </div>

        <div
          :if={@footer != []}
          class="flex flex-col gap-2 border-t border-stone-200 pt-4 sm:flex-row sm:items-center sm:justify-between"
        >
          {render_slot(@footer)}
        </div>
      </div>
    </div>
    """
  end

  slot :left, required: true
  slot :right
  attr :gap, :string, default: "gap-6"
  attr :class, :string, default: nil
  attr :left_class, :string, default: "flex-1 space-y-6"
  attr :right_class, :string, default: "space-y-6 lg:w-72"

  def two_column(assigns) do
    ~H"""
    <div class={["flex flex-col lg:flex-row", @gap, @class]}>
      <div class={@left_class}>
        {render_slot(@left)}
      </div>
      <aside :if={@right != []} class={@right_class}>
        {render_slot(@right)}
      </aside>
    </div>
    """
  end

  slot :inner_block, required: true
  attr :columns, :integer, default: 3
  attr :class, :string, default: nil

  def form_grid(assigns) do
    assigns =
      assign(assigns, :grid_class, grid_class(assigns[:columns]))

    ~H"""
    <div class={["grid gap-4", @grid_class, @class]}>
      {render_slot(@inner_block)}
    </div>
    """
  end

  attr :links, :list, required: true
  attr :id, :string, default: nil
  attr :class, :string, default: nil

  def toggle_bar(assigns) do
    ~H"""
    <div class={["bg-stone-200/60 inline-flex items-center justify-center rounded-lg p-1", @class]}>
      <.link
        :for={link <- @links}
        navigate={link.navigate}
        id={link[:id]}
        class={[
          "rounded-md px-3 py-1.5 text-sm font-medium transition",
          "text-stone-600 hover:text-stone-900",
          link[:active] && "bg-white text-stone-900 shadow"
        ]}
        data-active={link[:active]}
      >
        {link.label}
      </.link>
    </div>
    """
  end

  attr :for_id, :string, default: nil
  attr :text, :string, default: nil
  attr :rest, :global, default: %{}

  def filter_reset(assigns) do
    ~H"""
    <button
      type="button"
      class="inline-flex items-center gap-2 rounded-md border border-stone-200 px-3 py-2 text-sm font-medium text-stone-600 transition hover:border-stone-300 hover:text-stone-900"
      phx-click={JS.push("reset_filters", target: nil)}
      {@rest}
    >
      <span>{@text || "Reset filters"}</span>
    </button>
    """
  end

  defp grid_class(columns) when columns <= 1, do: "grid-cols-1"
  defp grid_class(2), do: "sm:grid-cols-2"
  defp grid_class(3), do: "sm:grid-cols-2 lg:grid-cols-3"
  defp grid_class(4), do: "sm:grid-cols-2 lg:grid-cols-4"
  defp grid_class(_), do: "sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4"
end
