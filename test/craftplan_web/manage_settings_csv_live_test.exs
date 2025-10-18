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
end
