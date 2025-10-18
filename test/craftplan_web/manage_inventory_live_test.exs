defmodule CraftplanWeb.ManageInventoryLiveTest do
  use CraftplanWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Craftplan.Test.Factory

  describe "index and new" do
    @tag role: :staff
    test "renders inventory index for staff", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/manage/inventory")
      assert has_element?(view, "#materials")
    end

    @tag role: :staff
    test "renders new material modal and creates material", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/manage/inventory/new")
      assert has_element?(view, "#material-form")

      params = %{
        "material" => %{
          "name" => "New Material",
          "sku" => "mat-" <> Ecto.UUID.generate(),
          "price" => "2.50",
          "unit" => "gram",
          "minimum_stock" => "0",
          "maximum_stock" => "0"
        }
      }

      view
      |> element("#material-form")
      |> render_submit(params)

      assert_patch(view, ~p"/manage/inventory")
      assert render(view) =~ "Material created successfully"
    end
  end

  describe "show tabs" do
    @tag role: :staff
    test "renders material details tab for staff", %{conn: conn} do
      material = Factory.create_material!()

      {:ok, view, _html} = live(conn, ~p"/manage/inventory/#{material.sku}")
      assert has_element?(view, "[role=tablist]")
      assert has_element?(view, "kbd")
    end

    @tag role: :staff
    test "renders allergens tab for staff", %{conn: conn} do
      material = Factory.create_material!()

      {:ok, view, _html} = live(conn, ~p"/manage/inventory/#{material.sku}/allergens")
      assert has_element?(view, "[role=tablist]")
      assert has_element?(view, "#material-allergen-form-2")
    end

    @tag role: :staff
    test "renders nutritional facts tab for staff", %{conn: conn} do
      material = Factory.create_material!()

      {:ok, view, _html} = live(conn, ~p"/manage/inventory/#{material.sku}/nutritional_facts")
      assert has_element?(view, "[role=tablist]")
      assert has_element?(view, "#material-nutritional-facts-form")
    end

    @tag role: :staff
    test "renders stock tab for staff", %{conn: conn} do
      material = Factory.create_material!()

      {:ok, view, _html} = live(conn, ~p"/manage/inventory/#{material.sku}/stock")
      assert has_element?(view, "[role=tablist]")
      assert has_element?(view, "#inventory_movements")
    end

    @tag role: :staff
    test "renders edit modal for staff", %{conn: conn} do
      material = Factory.create_material!()

      {:ok, view, _html} = live(conn, ~p"/manage/inventory/#{material.sku}/edit")
      assert has_element?(view, "#material-form")
    end

    @tag role: :staff
    test "renders adjust modal for staff", %{conn: conn} do
      material = Factory.create_material!()

      {:ok, view, _html} = live(conn, ~p"/manage/inventory/#{material.sku}/adjust")
      assert has_element?(view, "#movement-movment-form")
    end
  end
end
