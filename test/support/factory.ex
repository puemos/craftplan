defmodule Craftplan.Test.Factory do
  @moduledoc """
  Minimal factories for common domain entities used in tests.
  Uses Ash actions and passes a default staff actor when needed.
  """

  alias Craftplan.Catalog.Product
  alias Craftplan.Catalog.Recipe
  alias Craftplan.CRM.Customer
  alias Craftplan.Inventory.Allergen
  alias Craftplan.Inventory.Material
  alias Craftplan.Inventory.MaterialAllergen
  alias Craftplan.Orders.Order
  alias Craftplan.Organizations

  defp staff_actor, do: Craftplan.DataCase.staff_actor()

  def create_organization!(attrs \\ %{}, actor \\ Craftplan.DataCase.admin_actor()) do
    base_name = Map.get(attrs, :name, "Test Organization")

    slug =
      Map.get_lazy(attrs, :slug, fn ->
        base_name
        |> String.downcase()
        |> String.replace(~r/[^a-z0-9]+/, "-")
        |> Kernel.<>("-" <> Integer.to_string(System.unique_integer([:positive])))
      end)

    params =
      attrs
      |> Map.put(:name, base_name)
      |> Map.put(:slug, slug)
      |> Map.put_new(:status, :active)

    Organizations.create_organization!(params, actor: actor)
  end

  defp pop_organization(attrs) do
    {organization, rest} = Map.pop(attrs, :organization)

    cond do
      match?(%{__struct__: Craftplan.Organizations.Organization}, organization) ->
        {organization, rest}

      organization == nil ->
        {org_attrs, rest_without_attrs} = Map.pop(rest, :organization_attrs, %{})
        {create_organization!(org_attrs), rest_without_attrs}

      true ->
        raise ArgumentError, "expected :organization to be an Organizations.Organization struct"
    end
  end

  # Products
  def create_product!(attrs \\ %{}, actor \\ staff_actor()) do
    {organization, attrs} = pop_organization(attrs)

    params =
      %{
        name: Map.get(attrs, :name, "Test Product"),
        sku: Map.get(attrs, :sku, unique_code("SKU")),
        status: Map.get(attrs, :status, :active),
        price: Map.get(attrs, :price, Decimal.new("10.00"))
      }

    Product
    |> Ash.Changeset.for_create(:create, params)
    |> Organizations.put_tenant(organization)
    |> Ash.create!(actor: actor)
  end

  # Materials & Allergens
  def create_material!(attrs \\ %{}, actor \\ staff_actor()) do
    {organization, attrs} = pop_organization(attrs)

    params =
      %{
        name: Map.get(attrs, :name, "Test Material"),
        sku: Map.get(attrs, :sku, unique_code("MAT")),
        unit: Map.get(attrs, :unit, :gram),
        price: Map.get(attrs, :price, Decimal.new("1.00")),
        minimum_stock: Map.get(attrs, :minimum_stock, Decimal.new(0)),
        maximum_stock: Map.get(attrs, :maximum_stock, Decimal.new(0))
      }

    Material
    |> Ash.Changeset.for_create(:create, params)
    |> Organizations.put_tenant(organization)
    |> Ash.create!(actor: actor)
  end

  def add_allergen!(material, name \\ "Gluten", actor \\ staff_actor()) do
    allergen =
      Allergen |> Ash.Changeset.for_create(:create, %{name: name}) |> Ash.create!(actor: actor)

    _ =
      MaterialAllergen
      |> Ash.Changeset.for_create(:create, %{material_id: material.id, allergen_id: allergen.id})
      |> Ash.create!(actor: actor)

    Ash.reload!(material, load: [:allergens])
  end

  # Recipes
  def create_recipe!(product, components, actor \\ staff_actor()) do
    Recipe
    |> Ash.Changeset.for_create(:create, %{product_id: product.id, components: components})
    |> Ash.create!(actor: actor)
  end

  # Customers
  def create_customer!(attrs \\ %{}, _actor \\ staff_actor()) do
    {organization, attrs} = pop_organization(attrs)

    params =
      %{
        type: :individual,
        first_name: Map.get(attrs, :first_name, "Jane"),
        last_name: Map.get(attrs, :last_name, "Doe"),
        email: Map.get(attrs, :email, "jane.doe+#{System.unique_integer([:positive])}@local")
      }

    Customer
    |> Ash.Changeset.for_create(:create, params)
    |> Organizations.put_tenant(organization)
    |> Ash.create!()
  end

  # Orders
  def create_order_with_items!(customer, items, opts \\ []) do
    actor = Keyword.get(opts, :actor, staff_actor())
    delivery_date = Keyword.get(opts, :delivery_date, DateTime.utc_now())

    organization_id =
      Map.get(customer, :organization_id) ||
        raise ArgumentError, "customer must belong to an organization"

    params = %{
      customer_id: customer.id,
      delivery_date: delivery_date,
      items: items
    }

    {:ok, order} =
      Order
      |> Ash.Changeset.for_create(:create, params)
      |> Organizations.put_tenant(organization_id)
      |> Ash.create(actor: actor)

    Ash.reload!(order, load: [items: [product: [:name, :sku]]], actor: actor)
  end

  defp unique_code(prefix), do: String.downcase(prefix) <> "-" <> Ecto.UUID.generate()
end
