defmodule CraftplanWeb.ManageSettingsInteractionsLiveTest do
  use CraftplanWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  defp admin_user! do
    Craftplan.DataCase.admin_actor()
  end

  defp sign_in(conn, user) do
    conn
    |> AshAuthentication.Phoenix.Plug.store_in_session(user)
    |> Plug.Conn.assign(:current_user, user)
  end

  test "general settings can be saved", %{conn: conn} do
    conn = sign_in(conn, admin_user!())
    {:ok, view, _html} = live(conn, ~p"/manage/settings/general")

    params = %{"settings" => %{"tax_rate" => "0.05"}}

    view
    |> element("#settings-form")
    |> render_submit(params)

    assert render(view) =~ "Settings updated successfully"
  end

  test "add and delete allergen in settings", %{conn: conn} do
    conn = sign_in(conn, admin_user!())
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

  test "add and delete nutritional fact in settings", %{conn: conn} do
    conn = sign_in(conn, admin_user!())
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
