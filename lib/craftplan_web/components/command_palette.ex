defmodule CraftplanWeb.Components.CommandPalette do
  @moduledoc """
  Command palette LiveComponent for quick navigation and search.
  Triggered with Cmd+K (Mac) or Ctrl+K (Windows/Linux).
  """
  use CraftplanWeb, :live_component

  alias CraftplanWeb.CommandPaletteSearch

  @impl true
  def mount(socket) do
    {:ok,
     socket
     |> assign(:open, false)
     |> assign(:query, "")
     |> assign(:results, CommandPaletteSearch.search("", nil))
     |> assign(:selected_index, 0)
     |> assign(:flat_results, [])}
  end

  @impl true
  def update(assigns, socket) do
    # Only assign the incoming assigns, don't re-run search on every update
    {:ok, assign(socket, assigns)}
  end

  @impl true
  def handle_event("open", _params, socket) do
    results = CommandPaletteSearch.search("", socket.assigns[:current_user])
    flat = CommandPaletteSearch.flatten_results(results)

    {:noreply,
     socket
     |> assign(:open, true)
     |> assign(:query, "")
     |> assign(:results, results)
     |> assign(:flat_results, flat)
     |> assign(:selected_index, 0)}
  end

  @impl true
  def handle_event("close", _params, socket) do
    {:noreply, assign(socket, :open, false)}
  end

  @impl true
  def handle_event("search", %{"query" => query}, socket) do
    # Only update if the query actually changed
    if query == socket.assigns.query do
      {:noreply, socket}
    else
      results = CommandPaletteSearch.search(query, socket.assigns[:current_user])
      flat = CommandPaletteSearch.flatten_results(results)

      {:noreply,
       socket
       |> assign(:query, query)
       |> assign(:results, results)
       |> assign(:flat_results, flat)
       |> assign(:selected_index, 0)}
    end
  end

  @impl true
  def handle_event("navigate", %{"direction" => "down"}, socket) do
    max_index = max(0, length(socket.assigns.flat_results) - 1)
    new_index = min(socket.assigns.selected_index + 1, max_index)
    {:noreply, assign(socket, :selected_index, new_index)}
  end

  @impl true
  def handle_event("navigate", %{"direction" => "up"}, socket) do
    new_index = max(socket.assigns.selected_index - 1, 0)
    {:noreply, assign(socket, :selected_index, new_index)}
  end

  @impl true
  def handle_event("select", _params, socket) do
    case Enum.at(socket.assigns.flat_results, socket.assigns.selected_index) do
      nil ->
        {:noreply, socket}

      item ->
        send(self(), {:command_palette_navigate, item.path})
        {:noreply, assign(socket, :open, false)}
    end
  end

  @impl true
  def handle_event("select_item", %{"path" => path}, socket) do
    send(self(), {:command_palette_navigate, path})
    {:noreply, assign(socket, :open, false)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div
      id={@id}
      phx-hook="CommandPalette"
      phx-target={@myself}
      data-open={to_string(@open)}
    >
      <button
        type="button"
        phx-click="open"
        phx-target={@myself}
        class="hidden items-center gap-2 rounded-md border border-stone-200 bg-white px-3 py-1.5 text-sm text-stone-500 transition hover:border-stone-300 hover:text-stone-700 focus:outline-none focus:ring-2 focus:ring-stone-400 sm:flex"
        aria-label="Open command palette"
      >
        <svg class="h-4 w-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path
            stroke-linecap="round"
            stroke-linejoin="round"
            stroke-width="2"
            d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z"
          />
        </svg>
        <span class="hidden lg:inline">Search...</span>
        <.kbd class="hidden lg:inline-block">{cmd_key()}K</.kbd>
      </button>

      <div
        :if={@open}
        class="fixed inset-0 z-50 overflow-y-auto"
        role="dialog"
        aria-modal="true"
      >
        <div
          class="bg-stone-900/50 fixed inset-0 backdrop-blur-sm"
          phx-click="close"
          phx-target={@myself}
        />

        <div class="top-[15%] fixed inset-x-0 mx-auto w-full max-w-xl px-4">
          <div class="overflow-hidden rounded-lg bg-white shadow-2xl ring-1 ring-stone-200">
            <form phx-change="search" phx-target={@myself} class="flex items-center gap-3 border-b border-stone-200 px-4">
              <svg
                class="h-5 w-5 text-stone-400"
                fill="none"
                stroke="currentColor"
                viewBox="0 0 24 24"
              >
                <path
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  stroke-width="2"
                  d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z"
                />
              </svg>
              <input
                id="command-palette-input"
                type="text"
                name="query"
                value={@query}
                phx-debounce="150"
                placeholder="Search pages, actions, or records..."
                class="h-12 flex-1 border-0 bg-transparent text-sm text-stone-900 placeholder:text-stone-400 focus:outline-none focus:ring-0"
                autofocus
                autocomplete="off"
                phx-mounted={Phoenix.LiveView.JS.focus()}
              />
              <.kbd>esc</.kbd>
            </form>

            <div class="max-h-[60vh] overflow-y-auto p-2">
              <.result_section
                :if={@results.pages != []}
                title="Pages"
                items={@results.pages}
                flat_results={@flat_results}
                selected_index={@selected_index}
                myself={@myself}
              />

              <.result_section
                :if={@results.actions != []}
                title="Actions"
                items={@results.actions}
                flat_results={@flat_results}
                selected_index={@selected_index}
                myself={@myself}
              />

              <.result_section
                :if={@results.products != []}
                title="Products"
                items={@results.products}
                flat_results={@flat_results}
                selected_index={@selected_index}
                myself={@myself}
              />

              <.result_section
                :if={@results.materials != []}
                title="Materials"
                items={@results.materials}
                flat_results={@flat_results}
                selected_index={@selected_index}
                myself={@myself}
              />

              <.result_section
                :if={@results.orders != []}
                title="Orders"
                items={@results.orders}
                flat_results={@flat_results}
                selected_index={@selected_index}
                myself={@myself}
              />

              <.result_section
                :if={@results.customers != []}
                title="Customers"
                items={@results.customers}
                flat_results={@flat_results}
                selected_index={@selected_index}
                myself={@myself}
              />

              <.result_section
                :if={@results.suppliers != []}
                title="Suppliers"
                items={@results.suppliers}
                flat_results={@flat_results}
                selected_index={@selected_index}
                myself={@myself}
              />

              <.result_section
                :if={@results.purchase_orders != []}
                title="Purchase Orders"
                items={@results.purchase_orders}
                flat_results={@flat_results}
                selected_index={@selected_index}
                myself={@myself}
              />

              <.result_section
                :if={@results.batches != []}
                title="Production Batches"
                items={@results.batches}
                flat_results={@flat_results}
                selected_index={@selected_index}
                myself={@myself}
              />

              <div
                :if={empty_results?(@results)}
                class="py-8 text-center text-sm text-stone-500"
              >
                No results found for "{@query}"
              </div>
            </div>

            <div class="flex items-center justify-between border-t border-stone-200 px-4 py-2 text-xs text-stone-400">
              <div class="flex items-center gap-4">
                <span class="flex items-center gap-1">
                  <.kbd>↑</.kbd>
                  <.kbd>↓</.kbd>
                  to navigate
                </span>
                <span class="flex items-center gap-1">
                  <.kbd>↵</.kbd>
                  to select
                </span>
              </div>
              <span class="flex items-center gap-1">
                <.kbd>esc</.kbd>
                to close
              </span>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end

  attr :title, :string, required: true
  attr :items, :list, required: true
  attr :flat_results, :list, required: true
  attr :selected_index, :integer, required: true
  attr :myself, :any, required: true

  defp result_section(assigns) do
    ~H"""
    <div class="mb-2">
      <div class="px-3 py-1.5 text-xs font-semibold uppercase tracking-wide text-stone-400">
        {@title}
      </div>
      <ul>
        <li :for={item <- @items}>
          <% global_index = Enum.find_index(@flat_results, fn r -> r.path == item.path end) %>
          <button
            type="button"
            phx-click="select_item"
            phx-value-path={item.path}
            phx-target={@myself}
            class={[
              "flex w-full items-center gap-3 rounded-md px-3 py-2 text-left text-sm transition",
              if(global_index == @selected_index,
                do: "bg-stone-100 text-stone-900",
                else: "text-stone-700 hover:bg-stone-50"
              )
            ]}
          >
            <.result_icon icon={item[:icon]} />
            <div class="min-w-0 flex-1">
              <div class="truncate font-medium">{item.label}</div>
              <div :if={item[:sublabel]} class="truncate text-xs text-stone-500">
                {item.sublabel}
              </div>
            </div>
            <svg
              :if={global_index == @selected_index}
              class="h-4 w-4 text-stone-400"
              fill="none"
              stroke="currentColor"
              viewBox="0 0 24 24"
            >
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5l7 7-7 7" />
            </svg>
          </button>
        </li>
      </ul>
    </div>
    """
  end

  attr :icon, :atom, default: nil

  defp result_icon(assigns) do
    ~H"""
    <div class="flex h-8 w-8 shrink-0 items-center justify-center rounded-md bg-stone-100 text-stone-600">
      <%= case @icon do %>
        <% :manage -> %>
          <svg class="h-4 w-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path
              stroke-linecap="round"
              stroke-linejoin="round"
              stroke-width="2"
              d="M9 5H7a2 2 0 00-2 2v12a2 2 0 002 2h10a2 2 0 002-2V7a2 2 0 00-2-2h-2M9 5a2 2 0 002 2h2a2 2 0 002-2M9 5a2 2 0 012-2h2a2 2 0 012 2"
            />
          </svg>
        <% :production -> %>
          <svg class="h-4 w-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path
              stroke-linecap="round"
              stroke-linejoin="round"
              stroke-width="2"
              d="M3 7l9-4 9 4-9 4-9-4m9 4v10"
            />
          </svg>
        <% :inventory -> %>
          <svg class="h-4 w-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path
              stroke-linecap="round"
              stroke-linejoin="round"
              stroke-width="2"
              d="M4 6h16M4 10h16M4 14h16M4 18h16"
            />
          </svg>
        <% :purchasing -> %>
          <svg class="h-4 w-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path
              stroke-linecap="round"
              stroke-linejoin="round"
              stroke-width="2"
              d="M7 4h10l1 3H6l1-3zm-1 5h12l1 9H5l1-9zm3 4h4"
            />
          </svg>
        <% :products -> %>
          <svg class="h-4 w-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path
              stroke-linecap="round"
              stroke-linejoin="round"
              stroke-width="2"
              d="M12 3l9 4.5-9 4.5-9-4.5L12 3zm0 9l9-4.5v9L12 21v-9zm0 0L3 7.5v9L12 21"
            />
          </svg>
        <% :orders -> %>
          <svg class="h-4 w-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path
              stroke-linecap="round"
              stroke-linejoin="round"
              stroke-width="2"
              d="M9 12l2 2 4-4m4 10H5a2 2 0 01-2-2V6a2 2 0 012-2h11l4 4v12a2 2 0 01-2 2z"
            />
          </svg>
        <% :customers -> %>
          <svg class="h-4 w-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path
              stroke-linecap="round"
              stroke-linejoin="round"
              stroke-width="2"
              d="M17 20h5v-1a6 6 0 00-9-5.197M9 20H4v-1a6 6 0 0112 0v1zm3-9a4 4 0 100-8 4 4 0 000 8z"
            />
          </svg>
        <% :settings -> %>
          <svg class="h-4 w-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path
              stroke-linecap="round"
              stroke-linejoin="round"
              stroke-width="2"
              d="M10.325 4.317c.426-1.756 2.924-1.756 3.35 0a1.724 1.724 0 002.573 1.066c1.543-.94 3.31.826 2.37 2.37a1.724 1.724 0 001.065 2.572c1.756.426 1.756 2.924 0 3.35a1.724 1.724 0 00-1.066 2.573c.94 1.543-.826 3.31-2.37 2.37a1.724 1.724 0 00-2.572 1.065c-.426 1.756-2.924 1.756-3.35 0a1.724 1.724 0 00-2.573-1.066c-1.543.94-3.31-.826-2.37-2.37a1.724 1.724 0 00-1.065-2.572c-1.756-.426-1.756-2.924 0-3.35a1.724 1.724 0 001.066-2.573c-.94-1.543.826-3.31 2.37-2.37.996.608 2.296.07 2.572-1.065z"
            />
            <circle
              cx="12"
              cy="12"
              r="3"
              stroke-width="2"
              stroke-linecap="round"
              stroke-linejoin="round"
            />
          </svg>
        <% _ -> %>
          <svg class="h-4 w-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <circle cx="12" cy="12" r="10" stroke-width="2" />
          </svg>
      <% end %>
    </div>
    """
  end

  defp empty_results?(results) do
    results.pages == [] and
      results.actions == [] and
      results.products == [] and
      results.materials == [] and
      results.orders == [] and
      results.customers == [] and
      results.suppliers == [] and
      results.purchase_orders == [] and
      results.batches == []
  end

  defp cmd_key do
    # This will show ⌘ on Mac, Ctrl on others
    # We use the Unicode command key symbol for Mac
    "⌘"
  end
end
