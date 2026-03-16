defmodule CraftplanWeb.Layouts do
  @moduledoc """
  This module holds different layouts used by your application.

  See the `layouts` directory for all templates available.
  The "root" layout is a skeleton rendered as part of the
  application router. The "app" layout is set as the default
  layout on both `use CraftplanWeb, :controller` and
  `use CraftplanWeb, :live_view`.
  """
  use CraftplanWeb, :html

  alias Phoenix.LiveView.JS

  embed_templates "layouts/*"

  attr :current_path, :string, default: ""
  attr :nav_section, :atom, default: nil
  attr :current_user, :any, default: nil
  attr :flash, :map, default: %{}
  attr :socket, :any, default: nil
  attr :page_title, :string, default: nil
  attr :nav_sub_links, :list, default: []
  attr :nav_sub_label, :string, default: nil
  attr :breadcrumbs, :list, default: []
  slot :inner_block, required: true

  def sidebar_layout(assigns) do
    current_path = assigns.current_path || ""
    nav_section = assigns.nav_section
    is_manage? = manage_path?(current_path, nav_section)
    manage_links = compute_links(current_path, nav_section, manage_links())
    shop_links = compute_links(current_path, nav_section, shop_links())

    if_result = if(is_manage?, do: manage_links, else: shop_links)

    active_primary_label =
      if_result
      |> Enum.find(nil, & &1.active)
      |> case do
        %{label: label} -> label
        _ -> nil
      end

    nav_sub_links =
      compute_sub_links(
        current_path,
        Map.get(assigns, :nav_sub_links, []),
        nav_section
      )

    nav_sub_label = Map.get(assigns, :nav_sub_label, active_primary_label)

    assigns =
      assigns
      |> assign(:current_path, current_path)
      |> assign(:is_manage?, is_manage?)
      |> assign(:manage_links, manage_links)
      |> assign(:shop_links, shop_links)
      |> assign(:nav_sub_links, nav_sub_links)
      |> assign(:nav_sub_label, nav_sub_label)
      |> assign(:breadcrumbs, Map.get(assigns, :breadcrumbs, []))

    ~H"""
    <div>
      <div class="md:hidden">
        <div
          id="mobile-sidebar-backdrop"
          class="bg-black/40 fixed inset-0 z-40 hidden"
          phx-click={hide_sidebar()}
          aria-hidden="true"
        />

        <aside
          id="mobile-sidebar-panel"
          class="fixed inset-y-0 left-0 z-50 w-72 -translate-x-full transform bg-stone-50 shadow-lg transition-transform duration-200 ease-in-out focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-stone-400"
          aria-label="Primary navigation"
        >
          <div class="flex h-16 items-center justify-between border-b border-stone-200 px-4">
            <.logo_link />
            <button
              type="button"
              class="rounded-md border border-stone-200 bg-white p-2 text-stone-600 transition hover:text-stone-900 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-stone-400"
              phx-click={hide_sidebar()}
              aria-label="Close navigation"
            >
              <.nav_icon name={:close} />
            </button>
          </div>

          <.sidebar_content
            is_manage?={@is_manage?}
            manage_links={@manage_links}
            shop_links={@shop_links}
            current_user={@current_user}
            nav_sub_links={@nav_sub_links}
            nav_sub_label={@nav_sub_label}
            variant={:mobile}
          />
        </aside>
      </div>

      <div class="flex min-h-screen bg-stone-50 text-stone-800">
        <aside
          class="bg-stone-50/90 hidden border-r border-stone-200 backdrop-blur md:fixed md:inset-y-0 md:flex md:w-72 md:flex-col"
          aria-label="Primary navigation"
        >
          <div class="min-h-14 flex items-center border-b border-stone-200 px-6">
            <.logo_link />
          </div>

          <.sidebar_content
            is_manage?={@is_manage?}
            manage_links={@manage_links}
            shop_links={@shop_links}
            current_user={@current_user}
            nav_sub_links={@nav_sub_links}
            nav_sub_label={@nav_sub_label}
            variant={:desktop}
          />
        </aside>

        <div class="flex w-full flex-col md:pl-72">
          <header class="bg-stone-50/90 min-h-14 flex items-center gap-3 border-b border-stone-200 sm:px-6 lg:px-8">
            <button
              type="button"
              class="ml-1 rounded-md border border-stone-200 bg-white p-2 text-stone-600 transition hover:text-stone-900 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-stone-400 md:hidden"
              phx-click={show_sidebar()}
              aria-label="Open navigation"
            >
              <.nav_icon name={:menu} />
            </button>

            <div class="flex flex-1 items-center justify-between gap-4">
              <div class="min-w-0">
                <.layout_breadcrumbs :if={!Enum.empty?(@breadcrumbs)} breadcrumbs={@breadcrumbs} />
                <h1
                  :if={Enum.empty?(@breadcrumbs) and @page_title}
                  class="truncate text-base font-semibold text-stone-800 sm:text-lg"
                >
                  {@page_title}
                </h1>
              </div>

              <div class="flex items-center gap-4">
                <.live_component
                  :if={@current_user && @socket}
                  module={CraftplanWeb.Components.CommandPalette}
                  id="command-palette"
                  current_user={@current_user}
                />
                <div :if={@current_user} class="relative">
                  <button
                    type="button"
                    phx-click={JS.toggle(to: "#user-dropdown")}
                    phx-click-away={JS.hide(to: "#user-dropdown")}
                    class="flex items-center gap-2 rounded-md border border-transparent px-3 py-1.5 text-sm font-medium text-stone-600 transition hover:text-stone-900 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-stone-400"
                    aria-haspopup="menu"
                    aria-expanded="false"
                  >
                    <.nav_icon name={:user} />
                    <span class="max-w-[12rem] hidden truncate sm:block">{@current_user.email}</span>
                    <.nav_icon name={:chevron_down} />
                  </button>
                  <div
                    id="user-dropdown"
                    class="absolute right-0 mt-2 hidden w-56 rounded-md border border-stone-200 bg-white py-2 shadow-lg"
                    role="menu"
                    aria-label="User menu"
                  >
                    <.link
                      :if={not @is_manage?}
                      navigate={~p"/manage/orders"}
                      class="flex items-center gap-2 px-4 py-2 text-sm text-stone-600 transition hover:bg-stone-50 hover:text-stone-900"
                      role="menuitem"
                    >
                      <.nav_icon name={:manage} /> Manage dashboard
                    </.link>
                    <.link
                      href={~p"/sign-out"}
                      class="flex items-center gap-2 px-4 py-2 text-sm text-stone-600 transition hover:bg-stone-50 hover:text-stone-900"
                      role="menuitem"
                    >
                      <.nav_icon name={:logout} /> Log out
                    </.link>
                  </div>
                </div>

                <div :if={is_nil(@current_user)}>
                  <.link href={~p"/sign-in"}>
                    <.button variant={:primary} size={:sm}>
                      Log in
                    </.button>
                  </.link>
                </div>
              </div>
            </div>
          </header>

          <main class="flex-1 px-4 py-6 sm:px-6 lg:px-8">
            <.flash_group flash={@flash} />
            {render_slot(@inner_block)}
          </main>
        </div>
      </div>
    </div>
    """
  end

  attr :is_manage?, :boolean, default: false
  attr :manage_links, :list, default: []
  attr :shop_links, :list, default: []
  attr :current_user, :any, default: nil
  attr :nav_sub_links, :list, default: []
  attr :nav_sub_label, :string, default: nil
  attr :variant, :atom, default: :desktop

  defp sidebar_content(assigns) do
    assigns =
      assign(assigns, :sub_nav_role, if(assigns.variant == :desktop, do: "tablist"))

    ~H"""
    <nav class="h-[calc(100vh-4rem)] flex flex-col justify-between overflow-y-auto px-4 pt-6 pb-6 md:h-full md:pb-8">
      <div>
        <p class="text-xs font-semibold uppercase tracking-wide text-stone-400">
          {(@is_manage? && "Manage") || "Browse"}
        </p>

        <% primary_links = if @is_manage?, do: @manage_links, else: @shop_links %>
        <ul class="mt-3 space-y-1">
          <li :for={link <- primary_links}>
            <.link
              navigate={link.navigate}
              class={nav_link_classes(link.active)}
              data-active={link.active}
            >
              <.nav_icon name={link.icon} />
              <span>{link.label}</span>
            </.link>
            <div :if={link.active and @nav_sub_links != []} class="mt-2 space-y-2">
              <p
                :if={@nav_sub_label}
                class="px-3 text-xs font-medium uppercase tracking-wide text-stone-400"
              >
                {@nav_sub_label}
              </p>
              <ul class="space-y-1 border-l border-stone-200 pl-4" role={@sub_nav_role}>
                <li :for={sub <- @nav_sub_links}>
                  <.link
                    patch={sub.navigate}
                    class={sub_nav_link_classes(sub.active)}
                    data-active={sub.active}
                    role={if(@sub_nav_role, do: "tab", else: nil)}
                  >
                    <span class="flex items-center gap-2">
                      <.nav_icon :if={sub[:icon]} name={sub.icon} class="h-3.5 w-3.5 text-stone-500" />
                      <span>{sub.label}</span>
                    </span>
                    <span :if={sub[:description]} class="block text-xs text-stone-400">
                      {sub.description}
                    </span>
                  </.link>
                </li>
              </ul>
            </div>
          </li>
        </ul>
      </div>

      <div
        :if={!@is_manage?}
        class="bg-stone-100/60 mt-6 rounded-lg border border-stone-200 p-4 text-sm text-stone-600"
      >
        <div :if={@current_user} class="space-y-3">
          <.link
            navigate={~p"/manage/orders"}
            class="flex items-center justify-between rounded-md border border-transparent bg-white px-3 py-2 text-sm font-medium text-stone-600 transition hover:border-stone-300 hover:text-stone-900"
          >
            <span>Open manage</span>
            <.nav_icon name={:chevron_right} />
          </.link>
        </div>

        <div :if={is_nil(@current_user)} class="space-y-3">
          <p>Ready to manage your production workflow?</p>
          <.link
            href={~p"/sign-in"}
            class="inline-flex items-center gap-2 rounded-md bg-black px-3 py-2 text-sm font-medium text-white transition hover:bg-stone-900"
          >
            <.nav_icon name={:login} class="text-white" /> Log in
          </.link>
        </div>
      </div>
    </nav>
    """
  end

  attr :name, :atom, required: true
  attr :class, :string, default: nil

  defp nav_icon(assigns) do
    classes =
      ["h-4 w-4 shrink-0", assigns.class]
      |> Enum.reject(&is_nil/1)
      |> Enum.join(" ")

    assigns = assign(assigns, :classes, classes)

    ~H"""
    <%= case @name do %>
      <% :production -> %>
        <svg class={@classes} fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path
            stroke-linecap="round"
            stroke-linejoin="round"
            stroke-width="2"
            d="M3 7l9-4 9 4-9 4-9-4m9 4v10"
          />
        </svg>
      <% :inventory -> %>
        <svg class={@classes} fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path
            stroke-linecap="round"
            stroke-linejoin="round"
            stroke-width="2"
            d="M4 6h16M4 10h16M4 14h16M4 18h16"
          />
        </svg>
      <% :purchasing -> %>
        <svg class={@classes} fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path
            stroke-linecap="round"
            stroke-linejoin="round"
            stroke-width="2"
            d="M7 4h10l1 3H6l1-3zm-1 5h12l1 9H5l1-9zm3 4h4"
          />
        </svg>
      <% :products -> %>
        <svg class={@classes} fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path
            stroke-linecap="round"
            stroke-linejoin="round"
            stroke-width="2"
            d="M12 3l9 4.5-9 4.5-9-4.5L12 3zm0 9l9-4.5v9L12 21v-9zm0 0L3 7.5v9L12 21"
          />
        </svg>
      <% :orders -> %>
        <svg class={@classes} fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path
            stroke-linecap="round"
            stroke-linejoin="round"
            stroke-width="2"
            d="M9 12l2 2 4-4m4 10H5a2 2 0 01-2-2V6a2 2 0 012-2h11l4 4v12a2 2 0 01-2 2z"
          />
        </svg>
      <% :customers -> %>
        <svg class={@classes} fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path
            stroke-linecap="round"
            stroke-linejoin="round"
            stroke-width="2"
            d="M17 20h5v-1a6 6 0 00-9-5.197M9 20H4v-1a6 6 0 0112 0v1zm3-9a4 4 0 100-8 4 4 0 000 8z"
          />
        </svg>
      <% :settings -> %>
        <svg class={@classes} fill="none" stroke="currentColor" viewBox="0 0 24 24">
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
      <% :home -> %>
        <svg class={@classes} fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path
            stroke-linecap="round"
            stroke-linejoin="round"
            stroke-width="2"
            d="M3 12l2-2m0 0l7-7 7 7M5 10v10a1 1 0 001 1h3m10-11l2 2m-2-2v10a1 1 0 01-1 1h-3m-6 0a1 1 0 001-1v-4a1 1 0 011-1h2a1 1 0 011 1v4a1 1 0 001 1h2"
          />
        </svg>
      <% :catalog -> %>
        <svg class={@classes} fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path
            stroke-linecap="round"
            stroke-linejoin="round"
            stroke-width="2"
            d="M12 6.253v13m0-13C10.832 5.477 9.246 5 7.5 5S4.168 5.477 3 6.253v13C4.168 18.477 5.754 18 7.5 18s3.332.477 4.5 1.253m0-13C13.168 5.477 14.754 5 16.5 5c1.747 0 3.332.477 4.5 1.253v13C19.832 18.477 18.247 18 16.5 18c-1.746 0-3.332.477-4.5 1.253"
          />
        </svg>
      <% :contact -> %>
        <svg class={@classes} fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path
            stroke-linecap="round"
            stroke-linejoin="round"
            stroke-width="2"
            d="M3 8l7.89 5.26a2 2 0 002.22 0L21 8M5 19h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v10a2 2 0 002 2z"
          />
        </svg>
      <% :about -> %>
        <svg class={@classes} fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path
            stroke-linecap="round"
            stroke-linejoin="round"
            stroke-width="2"
            d="M4.318 6.318a4.5 4.5 0 000 6.364L12 20.364l7.682-7.682a4.5 4.5 0 00-6.364-6.364L12 7.636l-1.318-1.318a4.5 4.5 0 00-6.364 0z"
          />
        </svg>
      <% :manage -> %>
        <svg class={@classes} fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path
            stroke-linecap="round"
            stroke-linejoin="round"
            stroke-width="2"
            d="M9 5H7a2 2 0 00-2 2v12a2 2 0 002 2h10a2 2 0 002-2V7a2 2 0 00-2-2h-2M9 5a2 2 0 002 2h2a2 2 0 002-2M9 5a2 2 0 012-2h2a2 2 0 012 2"
          />
        </svg>
      <% :logout -> %>
        <svg class={@classes} fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path
            stroke-linecap="round"
            stroke-linejoin="round"
            stroke-width="2"
            d="M17 16l4-4m0 0l-4-4m4 4H7m6 4v1a3 3 0 01-3 3H6a3 3 0 01-3-3V7a3 3 0 013-3h4a3 3 0 013 3v1"
          />
        </svg>
      <% :login -> %>
        <svg class={@classes} fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path
            stroke-linecap="round"
            stroke-linejoin="round"
            stroke-width="2"
            d="M8 9l4-4 4 4m-4-4v12"
          />
        </svg>
      <% :chevron_down -> %>
        <svg class={@classes} fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 9l-7 7-7-7" />
        </svg>
      <% :chevron_right -> %>
        <svg class={@classes} fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5l7 7-7 7" />
        </svg>
      <% :menu -> %>
        <svg class={@classes} fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path
            stroke-linecap="round"
            stroke-linejoin="round"
            stroke-width="2"
            d="M4 6h16M4 12h16M4 18h16"
          />
        </svg>
      <% :user -> %>
        <svg class={@classes} fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path
            stroke-linecap="round"
            stroke-linejoin="round"
            stroke-width="2"
            d="M20 21v-2a4 4 0 00-4-4H8a4 4 0 00-4 4v2"
          />
          <circle
            cx="12"
            cy="7"
            r="4"
            stroke-width="2"
            stroke-linecap="round"
            stroke-linejoin="round"
          />
        </svg>
      <% :close -> %>
        <svg class={@classes} fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path
            stroke-linecap="round"
            stroke-linejoin="round"
            stroke-width="2"
            d="M6 18L18 6M6 6l12 12"
          />
        </svg>
      <% _ -> %>
        <svg class={@classes} fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <circle cx="12" cy="12" r="10" stroke-width="2" />
        </svg>
    <% end %>
    """
  end

  defp nav_link_classes(true) do
    "group flex items-center gap-3 rounded-md border border-transparent bg-stone-200/70 px-3 py-2 text-sm font-medium text-stone-900 transition hover:bg-stone-200"
  end

  defp nav_link_classes(false) do
    "group flex items-center gap-3 rounded-md border border-transparent px-3 py-2 text-sm font-medium text-stone-600 transition hover:bg-stone-200/50 hover:text-stone-900"
  end

  defp sub_nav_link_classes(true) do
    "flex w-full items-start justify-between gap-2 rounded-md border border-transparent bg-stone-200/70 px-3 py-1.5 text-sm font-medium text-stone-900 transition hover:bg-stone-200"
  end

  defp sub_nav_link_classes(false) do
    "flex w-full items-start justify-between gap-2 rounded-md border border-transparent px-3 py-1.5 text-sm text-stone-600 transition hover:bg-stone-200/50 hover:text-stone-900"
  end

  defp show_sidebar(js \\ %JS{}) do
    js
    |> JS.remove_class("hidden", to: "#mobile-sidebar-backdrop")
    |> JS.remove_class("-translate-x-full", to: "#mobile-sidebar-panel")
  end

  defp hide_sidebar(js \\ %JS{}) do
    js
    |> JS.add_class("hidden", to: "#mobile-sidebar-backdrop")
    |> JS.add_class("-translate-x-full", to: "#mobile-sidebar-panel")
  end

  defp manage_path?(current_path, nav_section) do
    nav_section != nil or String.starts_with?(current_path, "/manage")
  end

  defp manage_links do
    [
      %{
        label: "Overview",
        navigate: ~p"/manage/overview",
        icon: :manage,
        nav_section: :overview,
        prefix: "/manage/overview"
      },
      %{
        label: "Production",
        navigate: ~p"/manage/production/schedule",
        icon: :production,
        nav_section: :production,
        prefix: "/manage/production"
      },
      %{
        label: "Inventory",
        navigate: ~p"/manage/inventory",
        icon: :inventory,
        nav_section: :inventory,
        prefix: "/manage/inventory"
      },
      %{
        label: "Purchasing",
        navigate: ~p"/manage/purchasing",
        icon: :purchasing,
        nav_section: :purchasing,
        prefix: "/manage/purchasing"
      },
      %{
        label: "Products",
        navigate: ~p"/manage/products",
        icon: :products,
        nav_section: :products,
        prefix: "/manage/products"
      },
      %{
        label: "Orders",
        navigate: ~p"/manage/orders",
        icon: :orders,
        nav_section: :orders,
        prefix: "/manage/orders"
      },
      %{
        label: "Customers",
        navigate: ~p"/manage/customers",
        icon: :customers,
        nav_section: :customers,
        prefix: "/manage/customers"
      },
      %{
        label: "Settings",
        navigate: ~p"/manage/settings",
        icon: :settings,
        nav_section: :settings,
        prefix: "/manage/settings"
      }
    ]
  end

  defp shop_links do
    [
      %{label: "Home", navigate: ~p"/", icon: :home, exact: "/"},
      %{label: "Log in", navigate: ~p"/sign-in", icon: :login, exact: "/sign-in"},
      %{label: "Reset password", navigate: ~p"/reset", icon: :settings, exact: "/reset"}
    ]
  end

  defp compute_links(current_path, nav_section, links) do
    Enum.map(links, fn link ->
      Map.put(link, :active, nav_active?(current_path, nav_section, link))
    end)
  end

  defp nav_active?(current_path, nav_section, %{nav_section: section} = link) when not is_nil(section) do
    nav_section == section or String.starts_with?(current_path, Map.get(link, :prefix, ""))
  end

  defp nav_active?(current_path, _nav_section, %{exact: exact}) when is_binary(exact) do
    current_path == exact
  end

  defp nav_active?(current_path, _nav_section, %{prefix: prefix}) when is_binary(prefix) do
    String.starts_with?(current_path, prefix)
  end

  defp nav_active?(_, _, _), do: false

  attr :breadcrumbs, :list, required: true

  defp layout_breadcrumbs(assigns) do
    assigns = assign(assigns, :count, Enum.count(assigns.breadcrumbs))

    ~H"""
    <nav class="flex min-w-0 items-center text-sm text-stone-500" aria-label="Breadcrumb">
      <ol class="flex min-w-0 items-center gap-2 whitespace-nowrap">
        <li
          :for={{crumb, index} <- Enum.with_index(@breadcrumbs)}
          class="flex min-w-0 items-center gap-2"
        >
          <.link
            :if={!Map.get(crumb, :current?, index == @count - 1)}
            navigate={Map.get(crumb, :path) || Map.get(crumb, :navigate)}
            class="truncate transition hover:text-stone-900 hover:underline"
          >
            {crumb.label}
          </.link>
          <span
            :if={Map.get(crumb, :current?, index == @count - 1)}
            class="truncate text-stone-900"
          >
            {crumb.label}
          </span>
          <span :if={index < @count - 1} class="text-stone-300">/</span>
        </li>
      </ol>
    </nav>
    """
  end

  defp compute_sub_links(_current_path, links, _nav_section) when not is_list(links), do: []

  defp compute_sub_links(current_path, links, _nav_section) do
    Enum.map(links, fn link ->
      navigate = Map.get(link, :navigate) || Map.get(link, :path)

      active =
        case Map.fetch(link, :active) do
          {:ok, value} ->
            value

          :error ->
            if is_binary(navigate) do
              current_path == navigate
            else
              false
            end
        end

      link
      |> Map.put(:navigate, navigate)
      |> Map.put(:active, active)
    end)
  end

  defp logo_link(assigns) do
    ~H"""
    <.link navigate={~p"/"} class="flex items-center gap-2">
      <img src="/images/logo.svg" alt="Logo" class="h-6 w-6" />
      <span class="text-base font-semibold tracking-wide text-stone-800">Craftplan</span>
    </.link>
    """
  end
end
