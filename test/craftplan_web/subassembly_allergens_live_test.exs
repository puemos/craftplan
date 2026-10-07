defmodule CraftplanWeb.SubassemblyAllergensLiveTest do
  use CraftplanWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Craftplan.Catalog.BOM
  alias Craftplan.Orders
  alias Craftplan.Test.Factory
  alias Decimal, as: D

  @tag role: :staff
  test "product and batch label declare a subassembly material's allergen", %{
    conn: conn,
    user: actor
  } do
    material = Factory.create_material!(%{name: "Nested flour"}, actor)
    Factory.add_allergen!(material, "Gluten", actor)
    blend = Factory.create_product!(%{name: "Blend"}, actor)
    finished = Factory.create_product!(%{name: "Finished product"}, actor)

    for {product, components} <- [
          {blend, [%{component_type: :material, material_id: material.id, quantity: D.new(10)}]},
          {finished, [%{component_type: :product, product_id: blend.id, quantity: D.new(2)}]}
        ] do
      BOM
      |> Ash.Changeset.for_create(:create, %{
        product_id: product.id,
        status: :active,
        components: components
      })
      |> Ash.create!(actor: actor)
    end

    {:ok, view, _} = live(conn, ~p"/manage/products/#{finished.sku}")
    assert has_element?(view, "span", "Gluten")

    {:ok, batch} =
      Orders.open_batch_with_allocations(%{product_id: finished.id, planned_qty: D.new(1)},
        actor: actor
      )

    {:ok, view, _} = live(conn, ~p"/manage/production/batches/#{batch.batch_code}/label")
    assert has_element?(view, "#label-allergens", "Gluten")
    assert has_element?(view, "#label-ingredients", "Nested flour")
  end
end
