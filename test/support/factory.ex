defmodule Craftplan.Test.Factory do
  @moduledoc """
  Minimal factories for common domain entities used in tests.
  Uses Ash actions and passes a default staff actor when needed.
  """

  alias Craftplan.CRM.Customer
  alias Craftplan.Catalog.{Product, Recipe}
  alias Craftplan.Inventory.{Material, Allergen, MaterialAllergen}
  alias Craftplan.Orders.Order

  defp staff_actor, do: Craftplan.DataCase.staff_actor()

  # Products
  def create_product!(attrs \\ %{}, actor \\ staff_actor()) do
    params =
      %{
        name: Map.get(attrs, :name, "Test Product"),
        sku: Map.get(attrs, :sku, unique_code("SKU")),
        status: Map.get(attrs, :status, :active),
        price: Map.get(attrs, :price, Decimal.new("10.00"))
      }

    Product
    |> Ash.Changeset.for_create(:create, params)
    |> Ash.create!(actor: actor)
  end

  # Materials & Allergens
  def create_material!(attrs \\ %{}, actor \\ staff_actor()) do
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
    |> Ash.create!(actor: actor)
  end

  def add_allergen!(material, name \\ "Gluten", actor \\ staff_actor()) do
    allergen = Allergen |> Ash.Changeset.for_create(:create, %{name: name}) |> Ash.create!(actor: actor)

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
    params =
      %{
        type: :individual,
        first_name: Map.get(attrs, :first_name, "Jane"),
        last_name: Map.get(attrs, :last_name, "Doe"),
        email: Map.get(attrs, :email, "jane.doe+#{System.unique_integer([:positive])}@local")
      }

    Customer
    |> Ash.Changeset.for_create(:create, params)
    |> Ash.create!()
  end

  # Orders
  def create_order_with_items!(customer, items, opts \\ []) do
    actor = Keyword.get(opts, :actor, staff_actor())
    delivery_date = Keyword.get(opts, :delivery_date, DateTime.utc_now())

    params = %{
      customer_id: customer.id,
      delivery_date: delivery_date,
      items: items
    }

    {:ok, order} =
      Order
      |> Ash.Changeset.for_create(:create, params)
      |> Ash.create(actor: actor)

    Ash.reload!(order, load: [items: [product: [:name, :sku]]], actor: actor)
  end

  defp unique_code(prefix), do: String.downcase(prefix) <> "-" <> Ecto.UUID.generate()
end

