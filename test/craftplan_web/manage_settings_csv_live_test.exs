defmodule CraftplanWeb.ManageSettingsCSVLiveTest do
  use CraftplanWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  @tag role: :admin
  test "renders CSV import/export forms", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/manage/settings/csv")

    assert has_element?(view, "#csv-import-form")
    assert has_element?(view, "#csv-template-download")
    assert has_element?(view, "#csv-export-form")
  end

  @tag role: :admin
  test "products dry-run import shows mapping preview", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/manage/settings/csv")

    csv = "name,sku,price\nProd A,PA-1,5.50\nProd B,PB-2,3.00\n"

    view
    |> element("#csv-import-form")
    |> render_submit(%{"entity" => "products", "delimiter" => ",", "dry_run" => "on", "csv_content" => csv})

    assert has_element?(view, "#csv-mapping-form")
  end

  @tag role: :admin
  test "products mapping UI appears on preview", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/manage/settings/csv")

    csv = "Product Name,Code,Cost,State\nProd A,PA-1,5.50,active\n"

    view
    |> element("#csv-import-form")
    |> render_submit(%{"entity" => "products", "delimiter" => ",", "dry_run" => "on", "csv_content" => csv})

    # Mapping selects for Products
    assert has_element?(view, "#csv-mapping-form")

    # Validate with explicit mapping
    view
    |> element("#csv-mapping-form")
    |> render_submit(%{"mapping" => %{"name" => "product name", "sku" => "code", "price" => "cost", "status" => "state"}})

    assert render(view) =~ "Dry run: 1 rows valid, 0 errors"
  end
end
