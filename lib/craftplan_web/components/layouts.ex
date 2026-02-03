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
                    <span class="hidden sm:block max-w-[12rem] truncate">{@current_user.email}</span>
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
    <nav class="flex items-center text-sm text-stone-500 overflow-hidden" aria-label="Breadcrumb">
      <div class="flex items-center gap-2 overflow-x-auto no-scrollbar">
      <ol class="inline-flex items-center gap-2">
        <li :for={{crumb, index} <- Enum.with_index(@breadcrumbs)} class="flex items-center gap-2">
          <.link
            :if={!Map.get(crumb, :current?, index == @count - 1)}
            navigate={Map.get(crumb, :path) || Map.get(crumb, :navigate)}
            class="transition hover:text-stone-900 hover:underline"
          >
            {crumb.label}
          </.link>
          <span
            :if={Map.get(crumb, :current?, index == @count - 1)}
            class="text-stone-900"
          >
            {crumb.label}
          </span>
          <span :if={index < @count - 1} class="text-stone-300">/</span>
        </li>
      </ol>
      </div>
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
      <svg
        class="h-7 w-7"
        xmlns="http://www.w3.org/2000/svg"
        width="66"
        height="54"
        viewBox="0 0 66 54"
        fill="none"
      >
        <g>
          <path
            d="M21.1262 0.100903C11.2779 1.06643 3.22266 5.53542 0.850231 11.3286C-0.418743 14.501 0.160571 18.0045 2.42266 20.7907L3.19507 21.7562L3.05714 30.2528C2.91921 39.3012 2.97438 40.0184 3.71922 41.5633C4.46405 43.1357 5.23647 43.6322 9.62271 45.4805C18.9745 49.4254 24.0504 51.2737 27.5539 52.0737C28.7677 52.3495 32.1884 52.7082 32.7401 52.5978C35.4987 52.1013 58.1472 47.0254 58.7265 46.7495C59.1679 46.5288 59.7196 46.0874 59.9955 45.7012C60.961 44.3771 60.9886 44.0736 61.0989 33.6184L61.2093 23.9907L61.6782 23.6321C62.6713 22.9149 63.9679 21.3976 64.492 20.3493C66.8093 15.632 64.2989 10.6665 58.092 7.63199C50.9195 4.12852 40.6022 1.25953 31.3884 0.211249C29.2366 0.0181442 22.9469 -0.0922018 21.1262 0.100903ZM28.8228 2.91472C31.8573 3.16299 35.1125 3.63196 38.6988 4.37679C42.9195 5.28715 42.8367 5.23197 40.0229 5.56301C35.5539 6.08715 31.416 7.38371 28.4366 9.12165C22.4504 12.5975 19.6642 18.1148 21.3745 22.9976C21.7331 24.0459 22.5607 25.2873 23.3883 26.0045C24.2159 26.7769 24.078 26.7769 21.7331 26.2252C18.2021 25.37 14.0089 23.6873 8.35373 20.901C5.12612 19.301 4.79509 19.1079 4.29853 18.3907C2.09162 15.1631 3.00197 11.3286 6.75372 8.29406C11.7469 4.26645 19.9676 2.28023 28.8228 2.91472ZM48.6575 8.29406C55.0299 8.87338 60.1058 11.301 61.761 14.5286C62.4782 15.9355 62.561 17.4803 61.9817 18.7217C61.4575 19.8252 60.6851 20.7631 59.6368 21.4804C58.3127 22.3907 58.2023 22.8045 58.2023 26.8873C58.2023 28.8183 58.1472 33.3701 58.092 36.9563C58.0092 42.6943 57.9541 43.5495 57.7058 43.8529C57.4575 44.1564 55.3058 44.6805 44.9333 46.9702C38.0919 48.4874 32.2711 49.7288 31.9953 49.7288C31.1953 49.7288 30.6711 49.3702 30.2573 48.5426C29.8711 47.7702 29.8711 47.5495 29.8711 43.9357C29.8711 41.8391 29.8987 37.0667 29.9539 33.3149C30.0366 25.5356 30.1194 26.0321 28.4366 25.5356C25.7056 24.7631 24.1056 23.0528 23.8021 20.6528C23.3883 17.4803 26.3952 13.3975 30.7263 11.1906C35.416 8.84579 42.285 7.74233 48.6575 8.29406ZM8.29856 24.1562C15.1124 27.577 21.5676 29.6459 26.147 29.839L27.1125 29.8666L27.0849 35.4115C27.0573 38.4736 27.0021 42.2805 26.947 43.9081C26.8642 46.2529 26.8918 47.053 27.1125 47.853C27.3608 48.8461 27.3608 48.8461 27.0021 48.8461C25.4849 48.8461 7.63649 41.7012 6.72613 40.7357C5.87096 39.8253 5.87096 39.577 6.00889 31.0804C6.09165 26.7494 6.20199 23.1907 6.28475 23.1907C6.31234 23.2183 7.25028 23.6597 8.29856 24.1562Z"
            fill="black"
          />
          <path
            d="M28.8228 2.91472C31.8573 3.16299 35.1125 3.63196 38.6988 4.37679C42.9195 5.28715 42.8367 5.23197 40.0229 5.56301C35.5539 6.08715 31.416 7.38371 28.4366 9.12165C22.4504 12.5975 19.6642 18.1148 21.3745 22.9976C21.7331 24.0459 22.5607 25.2873 23.3883 26.0045C24.2159 26.7769 24.078 26.7769 21.7331 26.2252C18.2021 25.37 14.0089 23.6873 8.35373 20.901C5.12612 19.301 4.79509 19.1079 4.29853 18.3907C2.09162 15.1631 3.00197 11.3286 6.75372 8.29406C11.7469 4.26645 19.9676 2.28023 28.8228 2.91472Z"
            fill="black"
          />
          <path
            d="M8.29856 24.1562C15.1124 27.577 21.5676 29.6459 26.147 29.839L27.1125 29.8666L27.0849 35.4115C27.0573 38.4736 27.0021 42.2805 26.947 43.9081C26.8642 46.2529 26.8918 47.053 27.1125 47.853C27.3608 48.8461 27.3608 48.8461 27.0021 48.8461C25.4849 48.8461 7.63649 41.7012 6.72613 40.7357C5.87096 39.8253 5.87096 39.577 6.00889 31.0804C6.09165 26.7494 6.20199 23.1907 6.28475 23.1907C6.31234 23.2183 7.25028 23.6597 8.29856 24.1562Z"
            fill="black"
          />
          <path
            d="M31.1677 13.232C29.1815 14.0596 28.1608 14.9424 27.4435 16.5424C26.5884 18.4183 26.7815 20.6803 27.9677 22.4735C28.4918 23.2735 28.6573 23.3838 29.1539 23.3838C29.8711 23.3838 30.5884 22.8597 30.7263 22.1976C30.8091 21.839 30.6987 21.4252 30.2849 20.7079C29.7056 19.5769 29.5953 18.6389 30.0366 17.7286C30.3953 16.9562 31.416 16.1286 32.2711 15.8803C33.6505 15.4941 34.1746 14.2527 33.3746 13.232C32.9608 12.7079 32.4367 12.6803 31.1677 13.232Z"
            fill="black"
          />
          <path
            d="M35.5539 31.0252C34.7263 31.3563 34.6988 31.6321 34.5608 37.4529C34.4505 42.7495 34.4505 42.9426 34.7815 43.3564C35.2505 43.9357 36.3539 43.9357 36.9608 43.3839L37.3746 42.9977L37.485 37.6184C37.5953 31.7425 37.5677 31.5218 36.6574 31.108C36.1057 30.8045 36.0781 30.8045 35.5539 31.0252Z"
            fill="black"
          />
        </g>
      </svg>
      <span class="text-base font-semibold tracking-wide text-stone-800">
        Craftplan
      </span>
    </.link>
    """
  end
end
