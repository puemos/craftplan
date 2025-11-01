defmodule CraftplanWeb.ManageProductsRecipeSimpleLiveTest do
  use CraftplanWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Craftplan.Catalog
  alias Craftplan.Catalog.BOM
  alias Craftplan.Catalog.Product
  alias Craftplan.Inventory.Material

  defp staff, do: Craftplan.DataCase.staff_actor()

  defp product! do
    Product
    |> Ash.Changeset.for_create(:create, %{
      name: "P-#{System.unique_integer()}",
      sku: "SKU-#{System.unique_integer()}",
      price: Decimal.new("5.00"),
      status: :active
    })
    |> Ash.create!(actor: staff())
  end

  defp material! do
    Material
    |> Ash.Changeset.for_create(:create, %{
      name: "Mat-#{System.unique_integer()}",
      sku: "MAT-#{System.unique_integer()}",
      unit: :gram,
      price: Decimal.new("1.00"),
      minimum_stock: Decimal.new(0),
      maximum_stock: Decimal.new(0)
    })
    |> Ash.create!(actor: staff())
  end

  @tag role: :staff
  test "simple mode: saving creates a new active version", %{conn: conn} do
    m = material!()
    p = product!()

    _active =
      BOM
      |> Ash.Changeset.for_create(:create, %{
        product_id: p.id,
        status: :active,
        components: [%{component_type: :material, material_id: m.id, quantity: Decimal.new(1)}]
      })
      |> Ash.create!(actor: staff())

    {:ok, view, _html} = live(conn, ~p"/manage/products/#{p.sku}/recipe")

    # Change quantity to 2 and save
    view
    |> element("#recipe-form")
    |> render_change(%{
      "recipe" => %{"components" => %{"0" => %{"material_id" => m.id, "quantity" => "2"}}}
    })

    view
    |> element("#recipe-form")
    |> render_submit(%{
      "recipe" => %{"components" => %{"0" => %{"material_id" => m.id, "quantity" => "2"}}}
    })

    assert render(view) =~ "Recipe saved successfully"

    # Reload and assert the new active version has quantity 2
    {:ok, _view2, html} = live(conn, ~p"/manage/products/#{p.sku}/recipe")
    assert html =~ "value=\"2\""

    # Domain-level check: there should be 2 versions now, latest active
    {:ok, boms} = Catalog.list_boms_for_product(%{product_id: p.id}, actor: staff())
    assert length(boms) == 2
    assert Enum.at(boms, 0).status == :active
  end

  @tag role: :staff
  test "simple mode: banner when viewing older version, and navigate to latest", %{conn: conn} do
    m = material!()
    p = product!()

    # v1 active
    _v1 =
      BOM
      |> Ash.Changeset.for_create(:create, %{
        product_id: p.id,
        status: :active,
        components: [%{component_type: :material, material_id: m.id, quantity: Decimal.new(1)}]
      })
      |> Ash.create!(actor: staff())

    # v2 draft (latest)
    _v2 =
      BOM
      |> Ash.Changeset.for_create(:create, %{
        product_id: p.id,
        status: :draft,
        components: [%{component_type: :material, material_id: m.id, quantity: Decimal.new(2)}]
      })
      |> Ash.create!(actor: staff())

    # Open recipe on older version (v1)
    {:ok, view, html} = live(conn, ~p"/manage/products/#{p.sku}/recipe?v=1")
    assert html =~ "You are viewing an older version"

    # Click Go to latest (which should navigate to v2)
    view
    |> element("button[phx-click=switch_version][phx-value-bom_version='2']")
    |> render_click()

    # Now the page is on v2; quantity 2 should be shown
    assert render(view) =~ "value=\"2\""
  end
end
