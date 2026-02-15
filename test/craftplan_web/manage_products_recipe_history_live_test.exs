defmodule CraftplanWeb.ManageProductsRecipeHistoryLiveTest do
  use CraftplanWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Craftplan.Catalog.BOM
  alias Craftplan.Catalog.Product
  alias Craftplan.Inventory.Material

  defp staff, do: Craftplan.DataCase.staff_actor()

  defp product! do
    Product
    |> Ash.Changeset.for_create(:create, %{
      name: "P-#{System.unique_integer()}",
      sku: "SKU-#{System.unique_integer()}",
      price: Money.new("5.00", :USD),
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
      price: Money.new("1.00", :USD),
      minimum_stock: Decimal.new(0),
      maximum_stock: Decimal.new(0)
    })
    |> Ash.create!(actor: staff())
  end

  @tag role: :staff
  test "history modal: view older version and return to latest", %{conn: conn} do
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

    # In simple mode, we no longer promote from the modal.
    # Instead, click "View" on v1, assert read-only banner, then go back to latest (v2).

    # Click View on version 1
    view
    |> element("#bom-history-modal-table button[phx-click=switch_version][phx-value-bom_version=\"1\"]")
    |> render_click()

    # Older version banner is shown and the quantity is 1 (read-only)
    html = render(view)
    assert html =~ "You are viewing an older version"
    assert html =~ "value=\"1\""

    # Go to latest (version 2) via the in-page banner button
    view
    |> element("button[phx-click=switch_version][phx-value-bom_version=\"2\"]", "Go to latest")
    |> render_click()

    html = render(view)
    assert html =~ "value=\"2\""
  end
end
