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
  test "products dry-run import shows summary", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/manage/settings/csv")

    csv = "name,sku,price\nProd A,PA-1,5.50\nProd B,PB-2,3.00\n"

    view
    |> element("#csv-import-form")
    |> render_submit(%{"entity" => "products", "delimiter" => ",", "dry_run" => "on", "csv_content" => csv})

    assert render(view) =~ "Dry run: 2 rows valid, 0 errors"
  end
end
