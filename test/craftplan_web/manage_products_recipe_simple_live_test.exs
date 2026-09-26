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

  for suffix <- ["", "-mobile"] do
    @tag role: :staff
    test "removing recipe rows via #{if suffix == "", do: "desktop", else: "mobile"} controls persists",
         %{conn: conn} do
      m = material!()
      p = product!()

      original =
        BOM
        |> Ash.Changeset.for_create(:create, %{
          product_id: p.id,
          status: :active,
          components: [%{material_id: m.id, quantity: 1}],
          labor_steps: [%{name: "Mix", duration_minutes: 10}]
        })
        |> Ash.create!(actor: staff())

      {:ok, view, _html} = live(conn, ~p"/manage/products/#{p.sku}/recipe")

      view |> element("#remove-component-0#{unquote(suffix)}") |> render_click()
      refute has_element?(view, "#recipe-form input[name$='[material_id]']")
      assert has_element?(view, "#recipe-form button[type=submit]:not([disabled])")

      view |> element("#remove-labor-0#{unquote(suffix)}") |> render_click()
      refute has_element?(view, "#recipe-form input[name$='[duration_minutes]']")
      view |> element("#recipe-form") |> render_submit()

      {:ok, active} = Catalog.get_active_bom_for_product(%{product_id: p.id}, actor: staff())
      active = Ash.load!(active, [:components, :labor_steps, :rollup], actor: staff())
      assert active.id != original.id
      assert active.components == []
      assert active.labor_steps == []
      assert Decimal.equal?(active.rollup.unit_cost, 0)

      original = Ash.load!(original, [:components, :labor_steps], actor: staff())
      assert length(original.components) == 1
      assert length(original.labor_steps) == 1

      {:ok, reloaded, _html} = live(conn, ~p"/manage/products/#{p.sku}/recipe")
      refute has_element?(reloaded, "#remove-component-0")
      refute has_element?(reloaded, "#remove-labor-0")
    end
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
  test "simple mode: editing labor steps persists", %{conn: conn} do
    m = material!()
    p = product!()

    _active =
      BOM
      |> Ash.Changeset.for_create(:create, %{
        product_id: p.id,
        status: :active,
        components: [%{component_type: :material, material_id: m.id, quantity: Decimal.new(1)}],
        labor_steps: [%{name: "Mix dough", duration_minutes: Decimal.new(10)}]
      })
      |> Ash.create!(actor: staff())

    {:ok, view, _html} = live(conn, ~p"/manage/products/#{p.sku}/recipe")

    assert render(view) =~ "Labor steps"

    params = %{
      "recipe" => %{
        "components" => %{"0" => %{"material_id" => m.id, "quantity" => "1"}},
        "labor_steps" => %{
          "0" => %{
            "name" => "Mix dough",
            "duration_minutes" => "15",
            "units_per_run" => "12",
            "rate_override" => "20"
          }
        },
        "notes" => ""
      }
    }

    view
    |> element("#recipe-form")
    |> render_submit(params)

    assert render(view) =~ "Recipe saved successfully"

    {:ok, active_bom} = Catalog.get_active_bom_for_product(%{product_id: p.id}, actor: staff())
    active_bom = Ash.load!(active_bom, [labor_steps: []], actor: staff(), authorize?: false)
    [step | _] = active_bom.labor_steps

    assert step.duration_minutes == Decimal.new("15")
    assert step.rate_override == Decimal.new("20")
    assert step.units_per_run == Decimal.new("12")
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
