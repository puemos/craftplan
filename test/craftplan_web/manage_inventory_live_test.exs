defmodule CraftplanWeb.ManageInventoryLiveTest do
  use CraftplanWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Craftplan.Inventory.Material

  defp staff_user! do
    Craftplan.DataCase.staff_actor()
  end

  defp unique_sku do
    "mat-" <> Ecto.UUID.generate()
  end

  defp create_material!(attrs \\ %{}) do
    staff = staff_user!()
    name = Map.get(attrs, :name, "Test Material")
    sku = Map.get(attrs, :sku, unique_sku())
    price = Map.get(attrs, :price, Decimal.new("1.23"))
    unit = Map.get(attrs, :unit, :gram)

    Material
    |> Ash.Changeset.for_create(:create, %{
      name: name,
      sku: sku,
      price: price,
      unit: unit,
      minimum_stock: Decimal.new(0),
      maximum_stock: Decimal.new(0)
    })
    |> Ash.create!(actor: staff)
  end

  defp sign_in(conn, user) do
    conn
    |> Plug.Test.put_req_cookie("timezone", "Etc/UTC")
    |> AshAuthentication.Phoenix.Plug.store_in_session(user)
    |> Plug.Conn.assign(:current_user, user)
  end

  describe "index and new" do
    test "renders inventory index for staff", %{conn: conn} do
      staff = staff_user!()
      conn = sign_in(conn, staff)

      {:ok, view, _html} = live(conn, ~p"/manage/inventory")
      assert has_element?(view, "#materials")
    end

    test "renders new material modal and creates material", %{conn: conn} do
      staff = staff_user!()
      conn = sign_in(conn, staff)

      {:ok, view, _html} = live(conn, ~p"/manage/inventory/new")
      assert has_element?(view, "#material-form")

      params = %{
        "material" => %{
          "name" => "New Material",
          "sku" => unique_sku(),
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
    test "renders material details tab for staff", %{conn: conn} do
      material = create_material!()
      staff = staff_user!()
      conn = sign_in(conn, staff)

      {:ok, view, _html} = live(conn, ~p"/manage/inventory/#{material.sku}")
      assert has_element?(view, "[role=tablist]")
      assert has_element?(view, "kbd")
    end

    test "renders allergens tab for staff", %{conn: conn} do
      material = create_material!()
      staff = staff_user!()
      conn = sign_in(conn, staff)

      {:ok, view, _html} = live(conn, ~p"/manage/inventory/#{material.sku}/allergens")
      assert has_element?(view, "[role=tablist]")
      assert has_element?(view, "#material-allergen-form-2")
    end

    test "renders nutritional facts tab for staff", %{conn: conn} do
      material = create_material!()
      staff = staff_user!()
      conn = sign_in(conn, staff)

      {:ok, view, _html} = live(conn, ~p"/manage/inventory/#{material.sku}/nutritional_facts")
      assert has_element?(view, "[role=tablist]")
      assert has_element?(view, "#material-nutritional-facts-form")
    end

    test "renders stock tab for staff", %{conn: conn} do
      material = create_material!()
      staff = staff_user!()
      conn = sign_in(conn, staff)

      {:ok, view, _html} = live(conn, ~p"/manage/inventory/#{material.sku}/stock")
      assert has_element?(view, "[role=tablist]")
      assert has_element?(view, "#inventory_movements")
    end

    test "renders edit modal for staff", %{conn: conn} do
      material = create_material!()
      staff = staff_user!()
      conn = sign_in(conn, staff)

      {:ok, view, _html} = live(conn, ~p"/manage/inventory/#{material.sku}/edit")
      assert has_element?(view, "#material-form")
    end

    test "renders adjust modal for staff", %{conn: conn} do
      material = create_material!()
      staff = staff_user!()
      conn = sign_in(conn, staff)

      {:ok, view, _html} = live(conn, ~p"/manage/inventory/#{material.sku}/adjust")
      assert has_element?(view, "#movement-movment-form")
    end
  end
end
