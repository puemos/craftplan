defmodule CraftplanWeb.ManageProductsRecipeProductComponentsLiveTest do
  use CraftplanWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Craftplan.Catalog.BOM
  alias Craftplan.Catalog.Product
  alias Craftplan.Inventory.Material

  defp staff, do: Craftplan.DataCase.staff_actor()

  defp product!(attrs \\ %{}) do
    defaults = %{
      name: "P-#{System.unique_integer()}",
      sku: "SKU-#{System.unique_integer()}",
      price: Money.new("5.00", :USD),
      status: :active
    }

    Product
    |> Ash.Changeset.for_create(:create, Map.merge(defaults, attrs))
    |> Ash.create!(actor: staff())
  end

  defp material!(attrs \\ %{}) do
    defaults = %{
      name: "Mat-#{System.unique_integer()}",
      sku: "MAT-#{System.unique_integer()}",
      unit: :gram,
      price: Money.new("1.00", :USD),
      minimum_stock: Decimal.new(0),
      maximum_stock: Decimal.new(0)
    }

    Material
    |> Ash.Changeset.for_create(:create, Map.merge(defaults, attrs))
    |> Ash.create!(actor: staff())
  end

  defp product_with_bom!(attrs \\ %{}) do
    require Ash.Query

    m = material!()
    p = product!(attrs)

    BOM
    |> Ash.Changeset.for_create(:create, %{
      product_id: p.id,
      status: :active,
      components: [%{component_type: :material, material_id: m.id, quantity: Decimal.new(10)}]
    })
    |> Ash.create!(actor: staff())

    # Reload product to get bom_unit_cost
    product_id = p.id

    Product
    |> Ash.Query.for_read(:read, %{})
    |> Ash.Query.filter(id == ^product_id)
    |> Ash.Query.load([:bom_unit_cost])
    |> Ash.read_one!(actor: staff())
  end

  @tag role: :staff
  test "shows Add Product button when products are available", %{conn: conn} do
    # Create a component product with a BOM
    _component_product = product_with_bom!(%{name: "Component Widget"})

    # Create the main product to edit
    main_product = product!(%{name: "Main Product"})

    BOM
    |> Ash.Changeset.for_create(:create, %{
      product_id: main_product.id,
      status: :active,
      components: []
    })
    |> Ash.create!(actor: staff())

    {:ok, _view, html} = live(conn, ~p"/manage/products/#{main_product.sku}/recipe")

    assert html =~ "Add Material"
    assert html =~ "Add Product"
  end

  @tag role: :staff
  test "current product is excluded from available products", %{conn: conn} do
    # Create another product so the modal can be opened
    _other_product = product_with_bom!(%{name: "AvailableWidget"})

    # Product that tries to add itself as a component
    p = product!(%{name: "SelfReferenceTest"})

    BOM
    |> Ash.Changeset.for_create(:create, %{
      product_id: p.id,
      status: :active,
      components: []
    })
    |> Ash.create!(actor: staff())

    {:ok, view, _html} = live(conn, ~p"/manage/products/#{p.sku}/recipe")

    # Open the product modal
    view
    |> element("button[phx-click=show_add_product_modal]")
    |> render_click()

    # Get only the modal content to check
    modal_html =
      view
      |> element("#product-picker")
      |> render()

    # The current product should not appear in the modal picker (but other products should)
    refute modal_html =~ "SelfReferenceTest"
    assert modal_html =~ "AvailableWidget"
  end

  @tag role: :staff
  test "can add product component and it displays correctly", %{conn: conn} do
    # Create a component product
    component_product = product_with_bom!(%{name: "Semi-Finished Good"})

    # Create the main product
    main_product = product!(%{name: "Final Product"})

    BOM
    |> Ash.Changeset.for_create(:create, %{
      product_id: main_product.id,
      status: :active,
      components: []
    })
    |> Ash.create!(actor: staff())

    {:ok, view, _html} = live(conn, ~p"/manage/products/#{main_product.sku}/recipe")

    # Open the product modal
    view
    |> element("button[phx-click=show_add_product_modal]")
    |> render_click()

    # Add the component product
    view
    |> element("button[phx-click=add_product][phx-value-product-id='#{component_product.id}']")
    |> render_click()

    html = render(view)

    # The product should appear in the recipe with a "Product" badge
    assert html =~ "Semi-Finished Good"
    assert html =~ "Product"
  end

  @tag role: :staff
  test "saving recipe with product component persists correctly", %{conn: conn} do
    # Create a component product with known cost
    component_product = product_with_bom!(%{name: "Sub-Assembly"})

    # Create the main product
    main_product = product!(%{name: "Assembly"})

    BOM
    |> Ash.Changeset.for_create(:create, %{
      product_id: main_product.id,
      status: :active,
      components: []
    })
    |> Ash.create!(actor: staff())

    {:ok, view, _html} = live(conn, ~p"/manage/products/#{main_product.sku}/recipe")

    # Open the product modal and add component product
    view
    |> element("button[phx-click=show_add_product_modal]")
    |> render_click()

    view
    |> element("button[phx-click=add_product][phx-value-product-id='#{component_product.id}']")
    |> render_click()

    # Set quantity and save
    params = %{
      "recipe" => %{
        "components" => %{
          "0" => %{
            "component_type" => "product",
            "product_id" => component_product.id,
            "quantity" => "2"
          }
        },
        "labor_steps" => %{},
        "notes" => ""
      }
    }

    view
    |> element("#recipe-form")
    |> render_submit(params)

    assert render(view) =~ "Recipe saved successfully"

    # Reload and verify
    {:ok, _view2, html} = live(conn, ~p"/manage/products/#{main_product.sku}/recipe")
    assert html =~ "Sub-Assembly"
    assert html =~ "value=\"2\""
  end
end
