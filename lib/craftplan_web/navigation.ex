defmodule CraftplanWeb.Navigation do
  @moduledoc """
  Central registry for sidebar sub-navigation links and breadcrumb trails.

  LiveViews call `assign/3` (or `assign/4`) from `handle_params/3` with the
  current section and a declarative breadcrumb trail so that the layout can
  render consistent navigation affordances.
  """
  use CraftplanWeb, :html

  alias CraftplanWeb.HtmlHelpers
  alias CraftplanWeb.ProductionBatchLive.Index, as: ProductionBatchIndex
  alias CraftplanWeb.ProductionBatchLive.Show, as: ProductionBatchShow
  alias CraftplanWeb.PurchasingLive.Index
  alias CraftplanWeb.PurchasingLive.Show
  alias CraftplanWeb.PurchasingLive.Suppliers
  alias Phoenix.Component
  alias Phoenix.LiveView.Socket

  @type section ::
          :orders
          | :inventory
          | :purchasing
          | :customers
          | :settings
          | :production
          | :overview

  # Orders nav helpers
  def orders_nav_visible?(socket), do: live_action(socket) in [:index, :new]

  def orders_table_active?(socket), do: Map.get(socket.assigns, :view_mode, "table") != "calendar"

  def orders_calendar_active?(socket), do: Map.get(socket.assigns, :view_mode) == "calendar"

  # Inventory nav helpers
  @inventory_material_actions [
    :index,
    :new,
    :edit,
    :show,
    :details,
    :allergens,
    :nutritional_facts,
    :stock,
    :adjust
  ]

  def inventory_material_active?(socket), do: live_action(socket) in @inventory_material_actions
  def inventory_forecast_active?(socket), do: live_action(socket) == :forecast
  def inventory_reorder_active?(socket), do: live_action(socket) == :reorder

  # Purchasing nav helpers
  def purchasing_orders_active?(socket), do: socket.view in [Index, Show]
  def purchasing_suppliers_active?(socket), do: socket.view == Suppliers

  # Settings nav helpers
  defp settings_active?(:general, socket), do: live_action(socket) in [:index, :general]
  defp settings_active?(slug, socket), do: live_action(socket) == slug
  def settings_general_active?(socket), do: settings_active?(:general, socket)
  def settings_allergens_active?(socket), do: settings_active?(:allergens, socket)
  def settings_nutrition_active?(socket), do: settings_active?(:nutritional_facts, socket)
  def settings_csv_active?(socket), do: settings_active?(:csv, socket)
  def settings_api_keys_active?(socket), do: settings_active?(:api_keys, socket)

  # Production nav helpers
  def production_weekly_active?(socket) do
    live_action(socket) in [:schedule, :make_sheet] and schedule_view(socket) == :week
  end

  def production_daily_active?(socket) do
    live_action(socket) in [:schedule, :make_sheet] and schedule_view(socket) == :day
  end

  def production_plan_active?(socket) do
    live_action(socket) == :plan
  end

  def production_batches_active?(socket) do
    socket.view in [ProductionBatchIndex, ProductionBatchShow]
  end

  defp live_action(socket), do: Map.get(socket.assigns, :live_action)
  defp schedule_view(socket), do: Map.get(socket.assigns, :schedule_view, :day)

  # Breadcrumb builders
  def crumb_order(%{reference: reference}) do
    %{label: HtmlHelpers.format_reference(reference), path: ~p"/manage/orders/#{reference}"}
  end

  def crumb_order_items(%{reference: reference}) do
    %{label: "Items", path: ~p"/manage/orders/#{reference}/items"}
  end

  def crumb_material(%{name: name, sku: sku}) do
    %{label: name, path: ~p"/manage/inventory/#{sku}"}
  end

  def crumb_material_allergens(material) do
    %{label: "Allergens", path: ~p"/manage/inventory/#{material.sku}/allergens"}
  end

  def crumb_material_nutrition(material) do
    %{label: "Nutrition", path: ~p"/manage/inventory/#{material.sku}/nutritional_facts"}
  end

  def crumb_material_stock(material) do
    %{label: "Stock", path: ~p"/manage/inventory/#{material.sku}/stock"}
  end

  def crumb_production_batch(%{batch_code: batch_code}) do
    %{label: batch_code, path: ~p"/manage/production/batches/#{batch_code}"}
  end

  def crumb_purchase_order(%{reference: reference}) do
    %{label: reference, path: ~p"/manage/purchasing/#{reference}"}
  end

  def crumb_purchase_order_items(%{reference: reference}) do
    %{label: "Items", path: ~p"/manage/purchasing/#{reference}/items"}
  end

  def crumb_purchase_order_add_item(%{reference: reference}) do
    %{label: "Add Item", path: ~p"/manage/purchasing/#{reference}/add_item"}
  end

  def crumb_supplier(%{name: name, id: id}) do
    %{label: name, path: ~p"/manage/purchasing/suppliers/#{id}/edit"}
  end

  def crumb_customer(%{full_name: full_name, reference: reference}) do
    %{label: full_name, path: ~p"/manage/customers/#{reference}"}
  end

  def crumb_customer_orders(customer) do
    %{label: "Orders", path: ~p"/manage/customers/#{customer.reference}/orders"}
  end

  def crumb_customer_statistics(customer) do
    %{label: "Statistics", path: ~p"/manage/customers/#{customer.reference}/statistics"}
  end

  defp sections do
    %{
      overview: %{
        label: "Overview",
        path: "/manage/overview",
        pages: %{},
        sub_links: []
      },
      orders: %{
        label: "Orders",
        path: "/manage/orders",
        pages: %{
          new: %{label: "New Order", path: "/manage/orders/new"},
          order: &__MODULE__.crumb_order/1,
          order_items: &__MODULE__.crumb_order_items/1
        },
        sub_links: [
          %{
            key: :orders_table,
            label: "Table",
            navigate: "/manage/orders?view=table",
            show?: &__MODULE__.orders_nav_visible?/1,
            active?: &__MODULE__.orders_table_active?/1
          },
          %{
            key: :orders_calendar,
            label: "Calendar",
            navigate: "/manage/orders?view=calendar",
            show?: &__MODULE__.orders_nav_visible?/1,
            active?: &__MODULE__.orders_calendar_active?/1
          }
        ]
      },
      inventory: %{
        label: "Inventory",
        path: "/manage/inventory",
        pages: %{
          new_material: %{label: "New Material", path: "/manage/inventory/new"},
          forecast: %{label: "Usage Forecast", path: "/manage/inventory/forecast"},
          reorder: %{label: "Reorder Planner", path: "/manage/inventory/forecast/reorder"},
          material: &__MODULE__.crumb_material/1,
          material_allergens: &__MODULE__.crumb_material_allergens/1,
          material_nutrition: &__MODULE__.crumb_material_nutrition/1,
          material_stock: &__MODULE__.crumb_material_stock/1
        },
        sub_links: [
          %{
            key: :materials,
            label: "Materials",
            navigate: "/manage/inventory",
            active?: &__MODULE__.inventory_material_active?/1
          },
          %{
            key: :forecast,
            label: "Usage Forecast",
            navigate: "/manage/inventory/forecast",
            active?: &__MODULE__.inventory_forecast_active?/1
          },
          %{
            key: :reorder,
            label: "Reorder Planner",
            navigate: "/manage/inventory/forecast/reorder",
            active?: &__MODULE__.inventory_reorder_active?/1
          }
        ]
      },
      purchasing: %{
        label: "Purchasing",
        path: "/manage/purchasing",
        pages: %{
          purchase_orders: %{label: "Purchase Orders", path: "/manage/purchasing"},
          new_purchase_order: %{label: "New Purchase Order", path: "/manage/purchasing/new"},
          purchase_order: &__MODULE__.crumb_purchase_order/1,
          po_items: &__MODULE__.crumb_purchase_order_items/1,
          po_add_item: &__MODULE__.crumb_purchase_order_add_item/1,
          suppliers: %{label: "Suppliers", path: "/manage/purchasing/suppliers"},
          new_supplier: %{label: "New Supplier", path: "/manage/purchasing/suppliers/new"},
          supplier: &__MODULE__.crumb_supplier/1
        },
        sub_links: [
          %{
            key: :purchase_orders,
            label: "Purchase Orders",
            navigate: "/manage/purchasing",
            active?: &__MODULE__.purchasing_orders_active?/1
          },
          %{
            key: :suppliers,
            label: "Suppliers",
            navigate: "/manage/purchasing/suppliers",
            active?: &__MODULE__.purchasing_suppliers_active?/1
          }
        ]
      },
      customers: %{
        label: "Customers",
        path: "/manage/customers",
        pages: %{
          new_customer: %{label: "New Customer", path: "/manage/customers/new"},
          customer: &__MODULE__.crumb_customer/1,
          customer_orders: &__MODULE__.crumb_customer_orders/1,
          customer_statistics: &__MODULE__.crumb_customer_statistics/1
        },
        sub_links: []
      },
      settings: %{
        label: "Settings",
        path: "/manage/settings",
        pages: %{
          general: %{label: "General Settings", path: "/manage/settings/general"},
          allergens: %{label: "Allergens", path: "/manage/settings/allergens"},
          nutritional_facts: %{
            label: "Nutritional Facts",
            path: "/manage/settings/nutritional_facts"
          },
          csv: %{label: "Import & Export", path: "/manage/settings/csv"},
          api_keys: %{label: "API Keys", path: "/manage/settings/api_keys"}
        },
        sub_links: [
          %{
            key: :general,
            label: "General",
            navigate: "/manage/settings/general",
            active?: &__MODULE__.settings_general_active?/1
          },
          %{
            key: :allergens,
            label: "Allergens",
            navigate: "/manage/settings/allergens",
            active?: &__MODULE__.settings_allergens_active?/1
          },
          %{
            key: :nutritional_facts,
            label: "Nutritional Facts",
            navigate: "/manage/settings/nutritional_facts",
            active?: &__MODULE__.settings_nutrition_active?/1
          },
          %{
            key: :csv,
            label: "Import & Export",
            navigate: "/manage/settings/csv",
            active?: &__MODULE__.settings_csv_active?/1
          },
          %{
            key: :api_keys,
            label: "API Keys",
            navigate: "/manage/settings/api_keys",
            active?: &__MODULE__.settings_api_keys_active?/1
          }
        ]
      },
      production: %{
        label: "Production",
        path: "/manage/production/plan",
        pages: %{
          plan: %{label: "Plan", path: "/manage/production/plan"},
          schedule: %{label: "Schedule", path: "/manage/production/schedule"},
          make_sheet: %{label: "Make Sheet", path: "/manage/production/make_sheet"},
          materials: %{label: "Materials", path: "/manage/production/materials"},
          batches: %{label: "Batches", path: "/manage/production/batches"},
          batch: &__MODULE__.crumb_production_batch/1
        },
        sub_links: [
          %{
            key: :plan,
            label: "Plan",
            navigate: "/manage/production/plan",
            active?: &__MODULE__.production_plan_active?/1
          },
          %{
            key: :weekly,
            label: "Weekly",
            navigate: "/manage/production/schedule?view=week",
            active?: &__MODULE__.production_weekly_active?/1
          },
          %{
            key: :daily,
            label: "Daily",
            navigate: "/manage/production/schedule?view=day",
            active?: &__MODULE__.production_daily_active?/1
          },
          %{
            key: :batches,
            label: "Batches",
            navigate: "/manage/production/batches",
            active?: &__MODULE__.production_batches_active?/1
          }
        ]
      }
    }
  end

  @resource_sections %{
    order: :orders,
    material: :inventory,
    purchase_order: :purchasing,
    supplier: :purchasing,
    customer: :customers
  }

  @doc """
  Assigns both breadcrumb and nav sub-link data to the socket.

  ## Examples

      socket
      |> Navigation.assign(:orders, [
        Navigation.root(:orders),
        Navigation.resource(:order, order)
      ])
  """
  @spec assign(Socket.t(), section(), list(), keyword()) ::
          Socket.t()
  def assign(socket, section, trail, _opts \\ []) do
    normalized_trail =
      trail
      |> List.wrap()
      |> Enum.map(&normalize_token/1)

    breadcrumbs = build_breadcrumbs(section, normalized_trail)
    nav_sub_links = nav_links_for(section, socket)

    socket
    |> Component.assign(:nav_sub_links, nav_sub_links)
    |> Component.assign(:breadcrumbs, breadcrumbs)
  end

  @doc """
  Helper to reference the root crumb for a section.
  """
  def root(section) when is_atom(section), do: {section, :root}

  @doc """
  Helper to reference a section-specific page crumb.
  """
  def page(section, slug, data \\ nil) when is_atom(section) and is_atom(slug), do: {section, slug, data}

  @doc """
  Helper to reference resource-backed breadcrumb entries (orders, suppliers, etc).
  """
  def resource(type, data) when is_atom(type), do: {type, data}

  defp nav_links_for(section, socket) do
    case Map.get(sections(), section) do
      %{sub_links: links} when is_list(links) ->
        links
        |> Enum.filter(&link_visible?(&1, socket))
        |> Enum.map(&materialize_link(&1, socket))

      _ ->
        []
    end
  end

  defp link_visible?(%{show?: fun}, socket) when is_function(fun, 1), do: fun.(socket)
  defp link_visible?(_, _), do: true

  defp materialize_link(link, socket) do
    link
    |> Map.take([:label, :navigate, :description, :icon])
    |> Map.put(:active, nav_active?(link, socket))
  end

  defp nav_active?(%{active?: fun}, socket) when is_function(fun, 1), do: fun.(socket)
  defp nav_active?(_, _), do: false

  defp build_breadcrumbs(section, tokens) do
    tokens =
      case tokens do
        [] -> [normalize_token(root(section))]
        _ -> tokens
      end

    crumbs =
      tokens
      |> Enum.map(&materialize_crumb/1)
      |> Enum.reject(&is_nil/1)

    total = Enum.count(crumbs)

    crumbs
    |> Enum.with_index()
    |> Enum.map(fn {crumb, idx} ->
      Map.put(crumb, :current?, idx == total - 1)
    end)
  end

  defp materialize_crumb({:custom, %{label: _} = crumb}) do
    Map.put_new(crumb, :path, Map.get(crumb, :path))
  end

  defp materialize_crumb({:section, section, slug, data}) do
    section_config = Map.fetch!(sections(), section)

    entry =
      case slug do
        :root ->
          %{label: section_config.label, path: section_config.path}

        _ ->
          section_config
          |> Map.get(:pages, %{})
          |> Map.fetch!(slug)
      end

    normalize_entry(entry, data, section, slug)
  end

  defp materialize_crumb(_), do: nil

  defp normalize_entry(entry, data, section, slug) when is_function(entry, 1),
    do: entry.(data) || raise_breadcrumb_error(section, slug)

  defp normalize_entry(%{label: _} = entry, _data, _section, _slug) do
    Map.put_new(entry, :path, Map.get(entry, :path))
  end

  defp normalize_entry(_, _, section, slug), do: raise_breadcrumb_error(section, slug)

  defp raise_breadcrumb_error(section, slug) do
    raise ArgumentError,
          "missing breadcrumb builder for #{inspect({section, slug})} – ensure the trail includes required data"
  end

  defp normalize_token(%{label: _} = crumb), do: {:custom, crumb}

  defp normalize_token({section, slug}) when is_atom(section) and is_atom(slug), do: {:section, section, slug, nil}

  defp normalize_token({section, slug, data}) when is_atom(section) and is_atom(slug), do: {:section, section, slug, data}

  defp normalize_token({resource, data}) when is_atom(resource) do
    case Map.fetch(@resource_sections, resource) do
      {:ok, section} ->
        {:section, section, resource, data}

      :error when is_map(data) ->
        {:custom, data}

      :error ->
        raise ArgumentError, "unknown breadcrumb token #{inspect({resource, data})}"
    end
  end
end
