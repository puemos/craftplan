defmodule CraftplanWeb.ImportModalComponentTest do
  use CraftplanWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  @tag role: :admin
  test "sticky stepper, tabbed mapping, and footer actions", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/manage/settings/csv")

    view
    |> element("button[phx-click=open_import][phx-value-entity=products]")
    |> render_click()

    assert has_element?(view, "#csv-mapping-modal-content .sticky.top-0")
    assert has_element?(view, "#csv-mapping-modal-next")

    csv = "name,sku,price\nBread,BRD-1,abc"

    params = %{
      "delimiter" => ",",
      "dry_run" => "true",
      "csv_content" => csv
    }

    view
    |> element("#csv-select-form")
    |> render_submit(params)

    assert has_element?(view, "#csv-mapping-form")

    # defaults should map correctly to headers
    mapping_params = %{"mapping" => %{"name" => "name", "sku" => "sku", "price" => "price", "status" => ""}}

    view
    |> element("#csv-mapping-form")
    |> render_submit(mapping_params)

    # Errors should disable Next to Import
    assert has_element?(view, "#csv-mapping-modal-next-import[disabled]")
    # And Errors tab should show a table header
    assert has_element?(view, "#csv-mapping-modal-content thead th", "Row")
  end
end
