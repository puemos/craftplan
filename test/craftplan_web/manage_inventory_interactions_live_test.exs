defmodule CraftplanWeb.ManageInventoryInteractionsLiveTest do
  use CraftplanWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Craftplan.Inventory.Allergen
  alias Craftplan.Inventory.Material
  alias Craftplan.Inventory.NutritionalFact

  defp staff_user! do
    Craftplan.DataCase.staff_actor()
  end

  defp sign_in(conn, user) do
    conn
    |> Plug.Test.put_req_cookie("timezone", "Etc/UTC")
    |> AshAuthentication.Phoenix.Plug.store_in_session(user)
    |> Plug.Conn.assign(:current_user, user)
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

  defp create_allergen! do
    Allergen
    |> Ash.Changeset.for_create(:create, %{name: "ALG-#{System.unique_integer()}"})
    |> Ash.create!(actor: staff_user!())
  end

  defp create_nf! do
    NutritionalFact
    |> Ash.Changeset.for_create(:create, %{name: "NF-#{System.unique_integer()}"})
    |> Ash.create!(actor: staff_user!())
  end

  test "adjust stock via set_total", %{conn: conn} do
    m = create_material!()
    conn = sign_in(conn, staff_user!())
    {:ok, view, _} = live(conn, ~p"/manage/inventory/#{m.sku}/adjust")

    params = %{"movement" => %{"material_id" => m.id, "quantity" => "5", "reason" => "test"}}

    view
    |> element("#movement-movment-form")
    |> render_submit(params)

    assert_patch(view, ~p"/manage/inventory/#{m.sku}/stock")
    assert render(view) =~ "Material created successfully"
  end

  test "adjust stock via add", %{conn: conn} do
    m = create_material!()
    conn = sign_in(conn, staff_user!())
    {:ok, view, _} = live(conn, ~p"/manage/inventory/#{m.sku}/adjust")

    view
    |> element("button[phx-click=toggle_adjustment_type][phx-value-type=add]")
    |> render_click()

    params = %{"movement" => %{"material_id" => m.id, "quantity" => "2", "reason" => "add"}}

    view
    |> element("#movement-movment-form")
    |> render_submit(params)

    assert_patch(view, ~p"/manage/inventory/#{m.sku}/stock")
    assert render(view) =~ "Material created successfully"
  end

  test "adjust stock via subtract", %{conn: conn} do
    m = create_material!()
    conn = sign_in(conn, staff_user!())
    {:ok, view, _} = live(conn, ~p"/manage/inventory/#{m.sku}/adjust")

    view
    |> element("button[phx-click=toggle_adjustment_type][phx-value-type=subtract]")
    |> render_click()

    params = %{"movement" => %{"material_id" => m.id, "quantity" => "1", "reason" => "sub"}}

    view
    |> element("#movement-movment-form")
    |> render_submit(params)

    assert_patch(view, ~p"/manage/inventory/#{m.sku}/stock")
    assert render(view) =~ "Material created successfully"
  end

  test "assign allergens to material", %{conn: conn} do
    m = create_material!()
    a = create_allergen!()
    conn = sign_in(conn, staff_user!())
    {:ok, view, _} = live(conn, ~p"/manage/inventory/#{m.sku}/allergens")

    params = %{"material" => %{}, "allergen_ids" => [a.id]}

    view
    |> element("#material-allergen-form-2")
    |> render_change(params)

    view
    |> element("#material-allergen-form-2")
    |> render_submit(params)

    assert render(view) =~ "Allergens updated successfully"
  end

  test "assign nutritional facts to material", %{conn: conn} do
    m = create_material!()
    _nf = create_nf!()
    conn = sign_in(conn, staff_user!())
    {:ok, view, _} = live(conn, ~p"/manage/inventory/#{m.sku}/nutritional_facts")

    # Open modal and click first available fact
    view
    |> element("button[phx-click=show_add_modal]")
    |> render_click()

    # Click any button inside the selection list
    view
    |> element("button[phx-click=add_nutritional_fact]")
    |> render_click(%{"fact-id" => "ignored"})

    view
    |> element("#material-nutritional-facts-form")
    |> render_submit(%{"material" => %{}})

    assert render(view) =~ "Save Nutritional Facts"
  end
end
