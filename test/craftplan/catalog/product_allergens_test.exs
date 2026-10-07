defmodule Craftplan.Catalog.ProductAllergensTest do
  use Craftplan.DataCase, async: true

  alias Craftplan.Catalog.BOM
  alias Craftplan.Catalog.Services.BOMRollup
  alias Craftplan.Orders
  alias Craftplan.Test.Factory
  alias Decimal, as: D

  defp bom!(product, components, actor) do
    BOM
    |> Ash.Changeset.for_create(:create, %{
      product_id: product.id,
      status: :active,
      components: components
    })
    |> Ash.create!(actor: actor)
  end

  defp material_component(material), do: %{component_type: :material, material_id: material.id, quantity: D.new(10)}

  defp product_component(product), do: %{component_type: :product, product_id: product.id, quantity: D.new(2)}

  defp allergen_names(product, actor),
    do: product |> Ash.reload!(load: [:allergens], actor: actor) |> Map.fetch!(:allergens) |> Enum.map(& &1.name)

  test "nested and shared subassemblies include deduplicated sorted material allergens" do
    actor = Craftplan.DataCase.staff_actor()
    flour = Factory.create_material!(%{name: "Material-#{Ecto.UUID.generate()}"})
    Factory.add_allergen!(flour, "Gluten", actor)
    milk = Factory.create_material!(%{name: "Material-#{Ecto.UUID.generate()}"})
    Factory.add_allergen!(milk, "Milk", actor)
    eggs = Factory.create_material!(%{name: "Material-#{Ecto.UUID.generate()}"})
    Factory.add_allergen!(eggs, "Eggs", actor)

    base = Factory.create_product!(%{name: "Product-#{Ecto.UUID.generate()}"})
    bom!(base, [material_component(flour)], actor)
    blend = Factory.create_product!(%{name: "Product-#{Ecto.UUID.generate()}"})
    bom!(blend, [product_component(base), material_component(milk)], actor)
    finished = Factory.create_product!(%{name: "Product-#{Ecto.UUID.generate()}"})

    bom =
      bom!(
        finished,
        [product_component(blend), product_component(base), material_component(eggs)],
        actor
      )

    assert allergen_names(finished, actor) == ["Eggs", "Gluten", "Milk"]
    components = BOMRollup.flatten_components(bom, D.new(1), actor: actor)
    assert D.equal?(components[flour.id], 60)
    assert D.equal?(components[milk.id], 20)
    assert D.equal?(components[eggs.id], 10)
    rollup = Ash.reload!(bom, load: [:rollup], actor: actor).rollup
    assert D.equal?(D.new(rollup.components_map[flour.id]), 60)

    {:ok, batch} =
      Orders.open_batch_with_allocations(%{product_id: finished.id, planned_qty: D.new(1)},
        actor: actor
      )

    assert batch.label_snapshot["allergens"] == ["Eggs", "Gluten", "Milk"]

    assert Enum.sort(Enum.map(batch.label_snapshot["ingredients"], & &1["name"])) ==
             Enum.sort([flour.name, milk.name, eggs.name])

    Factory.add_allergen!(flour, "Sesame", actor)
    assert allergen_names(finished, actor) == ["Eggs", "Gluten", "Milk", "Sesame"]

    assert Ash.reload!(batch, actor: actor).label_snapshot["allergens"] == [
             "Eggs",
             "Gluten",
             "Milk"
           ]
  end

  test "products without an active recipe do not contribute allergens" do
    actor = Craftplan.DataCase.staff_actor()
    no_recipe = Factory.create_product!(%{name: "Product-#{Ecto.UUID.generate()}"})
    assert allergen_names(no_recipe, actor) == []
    parent = Factory.create_product!(%{name: "Product-#{Ecto.UUID.generate()}"})
    bom!(parent, [product_component(no_recipe)], actor)
    assert allergen_names(parent, actor) == []
  end

  test "cyclic recipes terminate without duplicating root material quantities" do
    actor = Craftplan.DataCase.staff_actor()
    material = Factory.create_material!(%{name: "Material-#{Ecto.UUID.generate()}"})
    Factory.add_allergen!(material, "Gluten", actor)
    first = Factory.create_product!(%{name: "Product-#{Ecto.UUID.generate()}"})
    first_bom = bom!(first, [material_component(material)], actor)
    second = Factory.create_product!(%{name: "Product-#{Ecto.UUID.generate()}"})
    bom!(second, [product_component(first)], actor)

    first_bom =
      Ash.update!(
        first_bom,
        %{components: [material_component(material), product_component(second)]},
        action: :update,
        actor: actor
      )

    assert allergen_names(first, actor) == ["Gluten"]

    assert D.equal?(
             BOMRollup.flatten_components(first_bom, D.new(1), actor: actor)[material.id],
             10
           )
  end
end
