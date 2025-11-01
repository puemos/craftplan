defmodule CraftplanWeb.ManageProductsRecipeHistoryLiveTest do
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
  test "history modal: revert to previous active", %{conn: conn} do
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

    # Change to quantity 2 and save (creates new active version)
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

    # Open history modal
    view
    |> element("a.text-blue-700", "Show version history")
    |> render_click()

    # Make previous version active again (first promote_row button targets archived v1)
    view
    |> element("#bom-history-modal-table button[phx-click=promote_row]")
    |> render_click()

    # Reload and assert quantity reverted to 1
    {:ok, _view2, html} = live(conn, ~p"/manage/products/#{p.sku}/recipe")
    assert html =~ "value=\"1\""

    {:ok, boms} = Catalog.list_boms_for_product(%{product_id: p.id}, actor: staff())
    assert Enum.any?(boms, &(&1.status == :active))
  end
end
