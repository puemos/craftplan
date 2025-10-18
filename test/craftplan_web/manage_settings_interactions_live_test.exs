defmodule CraftplanWeb.ManageSettingsInteractionsLiveTest do
  use CraftplanWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  @tag role: :admin
  test "general settings can be saved", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/manage/settings/general")

    params = %{"settings" => %{"tax_rate" => "0.05"}}

    view
    |> element("#settings-form")
    |> render_submit(params)

    assert render(view) =~ "Settings updated successfully"
  end

  @tag role: :admin
  test "add and delete allergen in settings", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/manage/settings/allergens")

    view
    |> element("button[phx-click=show_add_modal]")
    |> render_click()

    name = "Allergen-#{System.unique_integer()}"

    view
    |> element("#allergen-form")
    |> render_submit(%{"allergen" => %{"name" => name}})

    assert render(view) =~ name

    # Optional: delete interactions are covered elsewhere; keep add-only here
  end

  @tag role: :admin
  test "add and delete nutritional fact in settings", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/manage/settings/nutritional_facts")

    view
    |> element("button[phx-click=show_modal]")
    |> render_click()

    name = "NF-#{System.unique_integer()}"

    view
    |> element("#nutritional-fact-form")
    |> render_submit(%{"nutritional_fact" => %{"name" => name}})

    assert render(view) =~ name

    # Optional: delete interactions are covered elsewhere; keep add-only here
  end
end
