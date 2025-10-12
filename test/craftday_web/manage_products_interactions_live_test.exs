defmodule CraftdayWeb.ManageProductsInteractionsLiveTest do
  use CraftdayWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Craftday.Catalog.Product
  alias Craftday.Inventory.Material

  defp staff_user! do
    Craftday.DataCase.staff_actor()
  end

  defp sign_in(conn, user) do
    conn
    |> Plug.Test.put_req_cookie("timezone", "Etc/UTC")
    |> AshAuthentication.Phoenix.Plug.store_in_session(user)
    |> Plug.Conn.assign(:current_user, user)
  end

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
    |> Ash.create!(actor: staff_user!())
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
    |> Ash.create!(actor: staff_user!())
  end

  @tag :skip
  test "product photos: set featured and save (skipped: S3 in test env)", _ do
    :ok
  end

  test "product recipe: add material and save", %{conn: conn} do
    product = create_product!()
    material = create_material!()
    conn = sign_in(conn, staff_user!())

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
    |> render_change(%{"recipe" => %{"components" => %{"0" => %{"material_id" => material.id, "quantity" => "1"}}}})

    view
    |> element("#recipe-form")
    |> render_submit(%{"recipe" => %{"product_id" => product.id, "components" => %{"0" => %{"material_id" => material.id, "quantity" => "1"}}}})

    assert render(view) =~ "Recipe updated successfully"
  end
end
