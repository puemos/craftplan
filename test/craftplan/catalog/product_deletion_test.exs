defmodule Craftplan.Catalog.ProductDeletionTest do
  use Craftplan.DataCase, async: true

  import Craftplan.Test.Factory

  alias Craftplan.Catalog.BOM
  alias Craftplan.Catalog.Product
  alias Craftplan.Inventory.Material

  setup do
    actor = staff_actor()

    product =
      create_product!(%{name: "Deletion product #{System.unique_integer([:positive])}"}, actor)

    material =
      create_material!(%{name: "Deletion material #{System.unique_integer([:positive])}"}, actor)

    boms =
      for status <- [:archived, :active, :draft] do
        BOM
        |> Ash.Changeset.for_create(:create, %{
          product_id: product.id,
          status: status,
          components: [%{material_id: material.id, quantity: 2}],
          labor_steps: [%{name: "Mix", duration_minutes: 10}]
        })
        |> Ash.create!(actor: actor)
        |> Ash.load!([:components, :labor_steps, :rollup], actor: actor)
      end

    %{actor: actor, product: product, material: material, boms: boms}
  end

  test "deleting a product removes every recipe version and its owned records", context do
    %{actor: actor, product: product, material: material, boms: boms} = context

    assert :ok = Ash.destroy(product, actor: actor)
    assert is_nil(Ash.get!(Product, product.id, actor: actor, not_found_error?: false))
    assert Ash.get!(Material, material.id, actor: actor)

    for bom <- boms, record <- [bom, bom.rollup] ++ bom.components ++ bom.labor_steps do
      assert is_nil(Ash.get!(record.__struct__, record.id, actor: actor, not_found_error?: false))
    end
  end

  test "a product used in another recipe cannot be deleted", context do
    %{actor: actor, product: product, boms: boms} = context
    parent = create_product!(%{name: "Parent product"}, actor)

    BOM
    |> Ash.Changeset.for_create(:create, %{
      product_id: parent.id,
      components: [%{component_type: :product, product_id: product.id, quantity: 1}]
    })
    |> Ash.create!(actor: actor)

    assert {:error, _} = Ash.destroy(product, actor: actor)
    assert Ash.get!(Product, product.id, actor: actor)

    for bom <- boms, record <- [bom, bom.rollup] ++ bom.components ++ bom.labor_steps do
      assert Ash.get!(record.__struct__, record.id, actor: actor)
    end
  end

  test "a product used in an order cannot be deleted", context do
    %{actor: actor, product: product} = context
    customer = create_customer!()

    order =
      create_order_with_items!(
        customer,
        [%{product_id: product.id, quantity: 1, unit_price: product.price}],
        actor: actor
      )

    assert {:error, _} = Ash.destroy(product, actor: actor)
    assert Ash.get!(Product, product.id, actor: actor)
    assert Ash.get!(Craftplan.Orders.OrderItem, hd(order.items).id, actor: actor)
  end
end
