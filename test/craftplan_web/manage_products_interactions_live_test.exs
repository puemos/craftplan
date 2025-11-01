defmodule CraftplanWeb.ManageProductsInteractionsLiveTest do
  use CraftplanWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Craftplan.Catalog.Product
  alias Craftplan.Inventory.Material

  defp create_product!(attrs \\ %{}) do
    name = Map.get(attrs, :name, "P-#{System.unique_integer()}")
    sku = Map.get(attrs, :sku, "SKU-#{System.unique_integer()}")
    price = Map.get(attrs, :price, Decimal.new("4.00"))
    photos = Map.get(attrs, :photos, [])
    featured_photo = Map.get(attrs, :featured_photo, nil)

    Product
    |> Ash.Changeset.for_create(:create, %{
      name: name,
      sku: sku,
      price: price,
      status: :active,
      photos: photos,
      featured_photo: featured_photo
    })
    |> Ash.create!(actor: Craftplan.DataCase.staff_actor())
  end

  defp create_material! do
    Material
    |> Ash.Changeset.for_create(:create, %{
      name: "Mat-#{System.unique_integer()}",
      sku: "MAT-#{System.unique_integer()}",
      price: Decimal.new("1.00"),
      unit: :gram,
      minimum_stock: Decimal.new(0),
      maximum_stock: Decimal.new(0)
    })
    |> Ash.create!(actor: Craftplan.DataCase.staff_actor())
  end

  @tag :skip
  test "product photos: set featured and save (skipped: S3 in test env)", _ do
    :ok
  end

  @tag role: :staff
  test "product recipe: add material and save", %{conn: conn} do
    product = create_product!()
    material = create_material!()

    {:ok, view, _} = live(conn, ~p"/manage/products/#{product.sku}/recipe")

    # Open add material modal
    view
    |> element("button[phx-click=show_add_modal]")
    |> render_click()

    # Click the material option
    view
    |> element("button[phx-click=add_material][phx-value-material-id='#{material.id}']")
    |> render_click()

    # Set quantity for the added material then save
    view
    |> element("#recipe-form")
    |> render_change(%{
      "recipe" => %{"components" => %{"0" => %{"material_id" => material.id, "quantity" => "1"}}}
    })

    view
    |> element("#recipe-form")
    |> render_submit(%{
      "recipe" => %{
        "product_id" => product.id,
        "components" => %{"0" => %{"material_id" => material.id, "quantity" => "1"}}
      }
    })

    html = render(view)
    assert (html =~ "Recipe saved successfully") or (html =~ "Recipe updated successfully")
  end

  @tag role: :staff
  test "product recipe: added component persists across reload", %{conn: conn} do
    product = create_product!()
    material = create_material!()

    {:ok, view, _} = live(conn, ~p"/manage/products/#{product.sku}/recipe")

    view
    |> element("button[phx-click=show_add_modal]")
    |> render_click()

    view
    |> element("button[phx-click=add_material][phx-value-material-id='#{material.id}']")
    |> render_click()

    view
    |> element("#recipe-form")
    |> render_change(%{
      "recipe" => %{"components" => %{"0" => %{"material_id" => material.id, "quantity" => "2"}}}
    })

    view
    |> element("#recipe-form")
    |> render_submit(%{
      "recipe" => %{
        "product_id" => product.id,
        "components" => %{"0" => %{"material_id" => material.id, "quantity" => "2"}}
      }
    })

    assert_patch(view, ~p"/manage/products/#{product.sku}/recipe")

    # Reload
    {:ok, _view2, html} = live(conn, ~p"/manage/products/#{product.sku}/recipe")
    assert html =~ material.name
  end
end
