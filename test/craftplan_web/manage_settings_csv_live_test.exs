defmodule CraftplanWeb.ManageSettingsCSVLiveTest do
  use CraftplanWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  @tag role: :admin
  test "shows entity buttons and opens modal", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/manage/settings/csv")
    assert has_element?(view, "button[phx-click=open_import][phx-value-entity='products']")

    view
    |> element("button[phx-click=open_import][phx-value-entity='products']")
    |> render_click()

    assert has_element?(view, "#csv-mapping-modal")
  end

  @tag role: :admin
  test "products dry-run import shows mapping preview", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/manage/settings/csv")
    # Open modal for Products
    view
    |> element("button[phx-click=open_import][phx-value-entity='products']")
    |> render_click()

    csv = "name,sku,price\nProd A,PA-1,5.50\nProd B,PB-2,3.00\n"

    view
    |> element("#csv-select-form")
    |> render_submit(%{"delimiter" => ",", "dry_run" => "on", "csv_content" => csv})

    assert has_element?(view, "#csv-mapping-form")
  end

  @tag role: :admin
  test "products mapping UI appears on preview", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/manage/settings/csv")

    view
    |> element("button[phx-click=open_import][phx-value-entity='products']")
    |> render_click()

    csv = "Product Name,Code,Cost,State\nProd A,PA-1,5.50,active\n"

    view
    |> element("#csv-select-form")
    |> render_submit(%{"delimiter" => ",", "dry_run" => "on", "csv_content" => csv})

    assert has_element?(view, "#csv-mapping-form")

    view
    |> element("#csv-mapping-form")
    |> render_submit(%{
      "mapping" => %{
        "name" => "product name",
        "sku" => "code",
        "price" => "cost",
        "status" => "state"
      }
    })

    assert render(view) =~ "Dry run: 1 rows valid, 0 errors"
  end
end
