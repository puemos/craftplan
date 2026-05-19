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
      assert has_element?(view, "#movement-form")
    end
  end

  describe "movement form" do
    defp create_material_with_stock!(qty) do
      actor = Craftplan.DataCase.staff_actor()

      material =
        Craftplan.Inventory.Material
        |> Ash.Changeset.for_create(:create, %{
          name: "Test Stock Material",
          sku: "MAT-#{System.unique_integer([:positive])}",
          unit: :gram,
          price: Decimal.new("1.00"),
          minimum_stock: Decimal.new(0),
          maximum_stock: Decimal.new(0)
        })
        |> Ash.create!(actor: actor)

      lot =
        Craftplan.Inventory.Lot
        |> Ash.Changeset.for_create(:create, %{
          lot_code: "LOT-#{System.unique_integer([:positive])}",
          material_id: material.id
        })
        |> Ash.create!(actor: actor)

      Craftplan.Inventory.adjust_stock!(
        %{quantity: Decimal.new(qty), reason: "seed", material_id: material.id, lot_id: lot.id},
        actor: actor
      )

      Ash.reload!(material, load: [:current_stock])
    end

    @tag role: :staff
    test "subtract mode creates a negative movement", %{conn: conn} do
      material = create_material_with_stock!("100")
      actor = Craftplan.DataCase.staff_actor()

      {:ok, view, _html} = live(conn, ~p"/manage/inventory/#{material.sku}/adjust")

      view |> element("button[phx-value-mode=subtract]") |> render_click()

      view
      |> form("#movement-form", %{"movement" => %{"quantity" => "30", "reason" => "test sub"}})
      |> render_submit()

      assert_patch(view, ~p"/manage/inventory/#{material.sku}/stock")

      reloaded =
        Ash.load!(
          Craftplan.Inventory.get_material_by_id!(material.id, actor: actor),
          :current_stock,
          actor: actor
        )

      assert Decimal.equal?(reloaded.current_stock, Decimal.new("70"))
    end

    @tag role: :staff
    test "decimal quantity round-trips correctly", %{conn: conn} do
      material = create_material_with_stock!("50")
      actor = Craftplan.DataCase.staff_actor()

      {:ok, view, _html} = live(conn, ~p"/manage/inventory/#{material.sku}/adjust")

      view
      |> form("#movement-form", %{"movement" => %{"quantity" => "22.5", "reason" => "decimal"}})
      |> render_submit()

      assert_patch(view, ~p"/manage/inventory/#{material.sku}/stock")

      reloaded =
        Ash.load!(
          Craftplan.Inventory.get_material_by_id!(material.id, actor: actor),
          :current_stock,
          actor: actor
        )

      assert Decimal.equal?(reloaded.current_stock, Decimal.new("72.5"))
    end

    @tag role: :staff
    test "subtract below zero shows red preview without clamping", %{conn: conn} do
      material = create_material_with_stock!("10")

      {:ok, view, _html} = live(conn, ~p"/manage/inventory/#{material.sku}/adjust")

      view |> element("button[phx-value-mode=subtract]") |> render_click()

      html =
        view
        |> form("#movement-form", %{"movement" => %{"quantity" => "50"}})
        |> render_change()

      assert html =~ "text-red-600"
      assert html =~ "-40"
    end
  end
end
