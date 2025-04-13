defmodule MicrocraftWeb.Components.DataVis do
  @moduledoc false
  use Phoenix.Component
  use Gettext, backend: Microcraft.Gettext

  # import MicrocraftWeb.Components.Core
  # import MicrocraftWeb.Components.Utils
  # import MicrocraftWeb.HtmlHelpers

  # alias Phoenix.LiveView.JS

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
    <div class="table-fixed overflow-y-auto px-4 sm:overflow-visible sm:px-0">
      <table class={[
        "w-[40rem] table-fixed border-collapse sm:w-full",
        if(not @no_margin, do: "mt-11")
      ]}>
        <thead class="border-b border-stone-300 text-left text-sm leading-6 text-stone-500">
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
          class="relative divide-y divide-stone-200 text-sm leading-6 text-stone-700"
        >
          <tr :if={@empty != nil} id={"empty-#{@id}"} class="hidden only:block">
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
                @row_click && "hover:cursor-pointer"
              ]}
            >
              <div class="block py-4 pr-6">
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

  def stat_card(assigns) do
    ~H"""
    <div class="rounded-lg border border-stone-200 p-2">
      <dt :if={@title} class="text-sm font-medium text-stone-500">{@title}</dt>
      <dd class="mt-1">
        <div class="text-xl text-stone-900">{@value}</div>
        <div :if={@description} class="text-sm text-stone-500">{@description}</div>
      </dd>
    </div>
    """
  end
end
