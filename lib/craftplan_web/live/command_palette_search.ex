defmodule CraftplanWeb.CommandPaletteSearch do
  @moduledoc """
  Search functionality for the command palette.
  Provides static pages/actions and Ash-powered entity search.
  """
  import Ash.Query

  @pages [
    %{label: "Overview", path: "/manage/overview", icon: :manage},
    %{label: "Production Schedule", path: "/manage/production/schedule", icon: :production},
    %{label: "Production Batches", path: "/manage/production/batches", icon: :production},
    %{label: "Inventory", path: "/manage/inventory", icon: :inventory},
    %{label: "Forecast", path: "/manage/inventory/forecast", icon: :inventory},
    %{label: "Purchasing", path: "/manage/purchasing", icon: :purchasing},
    %{label: "Suppliers", path: "/manage/purchasing/suppliers", icon: :purchasing},
    %{label: "Products", path: "/manage/products", icon: :products},
    %{label: "Orders", path: "/manage/orders", icon: :orders},
    %{label: "Customers", path: "/manage/customers", icon: :customers},
    %{label: "Settings", path: "/manage/settings", icon: :settings}
  ]

  @actions [
    %{label: "New Order", path: "/manage/orders/new", icon: :orders},
    %{label: "New Product", path: "/manage/products/new", icon: :products},
    %{label: "New Material", path: "/manage/inventory/new", icon: :inventory},
    %{label: "New Customer", path: "/manage/customers/new", icon: :customers},
    %{label: "New Purchase Order", path: "/manage/purchasing/new", icon: :purchasing},
    %{label: "New Supplier", path: "/manage/purchasing/suppliers/new", icon: :purchasing}
  ]

  @doc """
  Searches all categories and returns grouped results.
  """
  def search(query, actor) when is_binary(query) do
    query = String.trim(query)

    if query == "" do
      %{
        pages: @pages,
        actions: @actions,
        products: [],
        materials: [],
        orders: [],
        customers: [],
        suppliers: [],
        purchase_orders: [],
        batches: []
      }
    else
      %{
        pages: search_static(@pages, query),
        actions: search_static(@actions, query),
        products: search_products(query, actor),
        materials: search_materials(query, actor),
        orders: search_orders(query, actor),
        customers: search_customers(query, actor),
        suppliers: search_suppliers(query, actor),
        purchase_orders: search_purchase_orders(query, actor),
        batches: search_batches(query, actor)
      }
    end
  end

  @doc """
  Returns all results as a flat list for keyboard navigation.
  """
  def flatten_results(results) do
    List.flatten([
      Enum.map(results.pages, &Map.put(&1, :category, :pages)),
      Enum.map(results.actions, &Map.put(&1, :category, :actions)),
      Enum.map(results.products, &Map.put(&1, :category, :products)),
      Enum.map(results.materials, &Map.put(&1, :category, :materials)),
      Enum.map(results.orders, &Map.put(&1, :category, :orders)),
      Enum.map(results.customers, &Map.put(&1, :category, :customers)),
      Enum.map(results.suppliers, &Map.put(&1, :category, :suppliers)),
      Enum.map(results.purchase_orders, &Map.put(&1, :category, :purchase_orders)),
      Enum.map(results.batches, &Map.put(&1, :category, :batches))
    ])
  end

  defp search_static(items, query) do
    pattern = String.downcase(query)

    items
    |> Enum.filter(fn item ->
      String.contains?(String.downcase(item.label), pattern)
    end)
    |> Enum.take(5)
  end

  defp search_products(query, actor) do
    pattern = "%#{query}%"

    Craftplan.Catalog.Product
    |> filter(ilike(name, ^pattern) or ilike(sku, ^pattern))
    |> limit(5)
    |> Ash.read!(actor: actor)
    |> Enum.map(fn p ->
      %{
        label: p.name,
        sublabel: p.sku,
        path: "/manage/products/#{p.sku}",
        icon: :products
      }
    end)
  rescue
    _ -> []
  end

  defp search_materials(query, actor) do
    pattern = "%#{query}%"

    Craftplan.Inventory.Material
    |> filter(ilike(name, ^pattern) or ilike(sku, ^pattern))
    |> limit(5)
    |> Ash.read!(actor: actor)
    |> Enum.map(fn m ->
      %{
        label: m.name,
        sublabel: m.sku,
        path: "/manage/inventory/#{m.sku}",
        icon: :inventory
      }
    end)
  rescue
    _ -> []
  end

  defp search_orders(query, actor) do
    pattern = "%#{query}%"

    Craftplan.Orders.Order
    |> filter(ilike(reference, ^pattern))
    |> limit(5)
    |> Ash.read!(actor: actor)
    |> Enum.map(fn o ->
      %{
        label: o.reference,
        sublabel: format_date(o.delivery_date),
        path: "/manage/orders/#{o.reference}",
        icon: :orders
      }
    end)
  rescue
    _ -> []
  end

  defp search_customers(query, actor) do
    pattern = "%#{query}%"

    Craftplan.CRM.Customer
    |> filter(ilike(first_name, ^pattern) or ilike(last_name, ^pattern) or ilike(reference, ^pattern))
    |> limit(5)
    |> Ash.read!(actor: actor)
    |> Enum.map(fn c ->
      %{
        label: "#{c.first_name} #{c.last_name}",
        sublabel: c.reference,
        path: "/manage/customers/#{c.reference}",
        icon: :customers
      }
    end)
  rescue
    _ -> []
  end

  defp search_suppliers(query, actor) do
    pattern = "%#{query}%"

    Craftplan.Inventory.Supplier
    |> filter(ilike(name, ^pattern))
    |> limit(5)
    |> Ash.read!(actor: actor)
    |> Enum.map(fn s ->
      %{
        label: s.name,
        sublabel: nil,
        path: "/manage/purchasing/suppliers",
        icon: :purchasing
      }
    end)
  rescue
    _ -> []
  end

  defp search_purchase_orders(query, actor) do
    pattern = "%#{query}%"

    Craftplan.Inventory.PurchaseOrder
    |> filter(ilike(reference, ^pattern))
    |> limit(5)
    |> Ash.read!(actor: actor)
    |> Enum.map(fn po ->
      %{
        label: po.reference,
        sublabel: format_status(po.status),
        path: "/manage/purchasing/#{po.reference}",
        icon: :purchasing
      }
    end)
  rescue
    _ -> []
  end

  defp search_batches(query, actor) do
    pattern = "%#{query}%"

    Craftplan.Orders.ProductionBatch
    |> filter(ilike(batch_code, ^pattern))
    |> limit(5)
    |> Ash.read!(actor: actor)
    |> Enum.map(fn b ->
      %{
        label: b.batch_code,
        sublabel: format_status(b.status),
        path: "/manage/production/batches/#{b.batch_code}",
        icon: :production
      }
    end)
  rescue
    _ -> []
  end

  defp format_date(nil), do: nil

  defp format_date(date) do
    Calendar.strftime(date, "%b %d, %Y")
  end

  defp format_status(nil), do: nil

  defp format_status(status) when is_atom(status), do: status |> Atom.to_string() |> String.replace("_", " ")

  defp format_status(status), do: to_string(status)
end
