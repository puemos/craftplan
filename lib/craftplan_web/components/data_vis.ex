defmodule CraftplanWeb.Components.DataVis do
  @moduledoc false
  use Phoenix.Component
  use Gettext, backend: Craftplan.Gettext

  # import CraftplanWeb.Components.Core
  # import CraftplanWeb.Components.Utils
  # import CraftplanWeb.HtmlHelpers

  # alias Phoenix.LiveView.JS

  attr :id, :string, default: nil
  attr :class, :string, default: nil
  attr :min_width, :string, default: "min-w-[1100px]"
  attr :aria_label, :string, default: "Scrollable table"
  attr :show_edges?, :boolean, default: true
  slot :inner_block, required: true

  def scroll_table(assigns) do
    ~H"""
    <div id={@id} class={["relative", @class]}>
      <div
        class="w-full overflow-x-auto overflow-y-hidden focus-visible:ring-primary-200 focus-visible:outline-none focus-visible:ring-2"
        tabindex="0"
        role="region"
        aria-label={@aria_label}
      >
        <div class={["inline-block min-w-full align-top", @min_width]}>
          {render_slot(@inner_block)}
        </div>
      </div>
    </div>
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

  attr :no_margin, :boolean,
    default: false,
    doc: "removes the default top margin when set to true"

  attr :row_item, :any,
    default: &Function.identity/1,
    doc: "the function for mapping each row before calling the :col and :action slots"

  attr :variant, :atom,
    default: :default,
    values: [:default, :compact],
    doc: "visual density variant"

  attr :zebra, :boolean, default: false, doc: "alternating row background stripes"
  attr :sticky_header, :boolean, default: false, doc: "sticky header at top of scroll container"
  attr :wrapper_class, :string, default: nil, doc: "extra classes for the outer wrapper"
  attr :table_class, :string, default: nil, doc: "extra classes for the table element"

  slot :col, required: true do
    attr :label, :string
    attr :align, :atom
  end

  slot :empty

  slot :action, doc: "the slot for showing user actions in the last table column"

  def table(assigns) do
    assigns =
      with %{rows: %Phoenix.LiveView.LiveStream{}} <- assigns do
        assign(assigns, row_id: assigns.row_id || fn {id, _item} -> id end)
      end

    ~H"""
    <div class={["table-fixed overflow-y-auto px-4 sm:overflow-visible sm:px-0", @wrapper_class]}>
      <table class={[
        "table-fixed border-collapse sm:w-full",
        if(not @no_margin, do: "mt-11"),
        @table_class
      ]}>
        <thead class={[
          "border-b border-stone-300 text-left text-sm leading-6 text-stone-500",
          @sticky_header && "sticky top-0 bg-white"
        ]}>
          <tr>
            <th
              :for={{col, i} <- Enum.with_index(@col)}
              class={[
                "border-r border-stone-200 p-0 pr-6 pb-4 font-normal last:border-r-0",
                i > 0 && "pl-4"
              ]}
            >
              {col[:label]}
            </th>
            <th
              :if={@action != []}
              class="relative border-r border-stone-200 p-0 pr-4 pb-4 last:border-r-0"
            >
              <span class="sr-only">{gettext("Actions")}</span>
            </th>
          </tr>
        </thead>
        <tbody
          id={@id}
          phx-update={match?(%Phoenix.LiveView.LiveStream{}, @rows) && "stream"}
          class={[
            "relative divide-y divide-stone-200 text-stone-700",
            (@variant == :compact && "text-sm leading-5") || "text-sm leading-6",
            @zebra && "[&_tr:nth-child(even)]:bg-stone-50"
          ]}
        >
          <tr :if={@empty != nil} id={"empty-#{@id}"} class="hidden last:table-row">
            <td colspan={Enum.count(@col)}>
              {render_slot(@empty)}
            </td>
          </tr>
          <tr :for={row <- @rows} id={@row_id && @row_id.(row)} class="group hover:bg-stone-200/40">
            <td
              :for={{col, i} <- Enum.with_index(@col)}
              phx-click={@row_click && @row_click.(row)}
              class={[
                "relative border-r border-b border-stone-200 p-0 last:border-r-0",
                i > 0 && "pl-4",
                @row_click && "hover:cursor-pointer",
                (Map.get(col, :align, :left) == :right && "text-right") ||
                  (Map.get(col, :align, :left) == :center && "text-center") || "text-left"
              ]}
            >
              <div class={["block pr-6", (@variant == :compact && "py-2") || "py-4"]}>
                <span class={["relative"]}>
                  {render_slot(col, @row_item.(row))}
                </span>
              </div>
            </td>
            <td
              :if={@action != []}
              class="relative w-14 border-r border-b border-stone-200 p-0 pr-4 last:border-r-0"
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
    <div>
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
  attr :title, :string, default: nil, doc: "The title of the statistic"
  attr :value, :any, default: nil, doc: "The main value to display"
  attr :description, :string, default: nil, doc: "Additional context for the statistic"
  attr :size, :atom,
    default: :md,
    values: [:sm, :md],
    doc: "Visual size variant (\":sm\" or \":md\")."

  def stat_card(assigns) do
    ~H"""
    <div class={["rounded border border-stone-200 bg-white", stat_card_container_classes(@size)]}>
      <dt :if={@title} class={stat_card_title_classes(@size)}>{@title}</dt>
      <dd class="mt-1">
        <div class={stat_card_value_classes(@size)}>{@value}</div>
        <div :if={@description} class={stat_card_desc_classes(@size)}>{@description}</div>
      </dd>
    </div>
    """
  end

  defp stat_card_container_classes(:sm), do: "p-2"
  defp stat_card_container_classes(:md), do: "p-3"

  defp stat_card_title_classes(:sm), do: "mb-3 text-sm font-medium text-stone-600"
  defp stat_card_title_classes(:md), do: "mb-5 text-base font-medium text-stone-600"

  defp stat_card_value_classes(:sm), do: "text-lg font-semibold text-stone-900"
  defp stat_card_value_classes(:md), do: "text-xl font-semibold text-stone-900"

  defp stat_card_desc_classes(:sm), do: "text-xs text-stone-500"
  defp stat_card_desc_classes(:md), do: "text-sm text-stone-500"

  @doc """
  Renders a table card with a title and table content.

  ## Examples

      <.table_card title="Orders Today">
        <.table id="orders" rows={@orders} variant={:compact} zebra no_margin>
          <:col :let={row} label="Reference">{row.reference}</:col>
          <:col :let={row} label="Total">{row.total}</:col>
        </.table>
      </.table_card>

  ## Attributes

    * `title` - The title of the table card (required)
    * `class` - Additional CSS classes for the card wrapper (optional)

  The component provides consistent card styling for tables, matching the stat_card design.
  """
  attr :title, :string, required: true, doc: "The title of the table card"
  attr :class, :string, default: nil, doc: "Additional CSS classes for the card wrapper"
  slot :inner_block, required: true

  def table_card(assigns) do
    ~H"""
    <div class={["rounded border border-stone-200 bg-white p-4", @class]}>
      <h3 class="mb-5 text-base font-medium text-stone-600">{@title}</h3>
      <div>
        {render_slot(@inner_block)}
      </div>
    </div>
    """
  end
end
