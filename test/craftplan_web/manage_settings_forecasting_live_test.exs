defmodule CraftplanWeb.ManageSettingsForecastingLiveTest do
  use CraftplanWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  describe "forecasting settings" do
    test "renders forecasting settings section", %{conn: conn} do
      admin = Craftplan.DataCase.admin_actor()

      conn =
        conn
        |> AshAuthentication.Phoenix.Plug.store_in_session(admin)
        |> Plug.Conn.assign(:current_user, admin)

      {:ok, _view, html} = live(conn, ~p"/manage/settings/general")

      assert html =~ "Inventory Forecasting"
      assert html =~ "Lookback days"
      assert html =~ "Default horizon"
      assert html =~ "Actual usage weight"
      assert html =~ "Planned usage weight"
      assert html =~ "Default service level"
      assert html =~ "Min samples for variability"
    end

    test "can update forecasting settings", %{conn: conn} do
      admin = Craftplan.DataCase.admin_actor()

      conn =
        conn
        |> AshAuthentication.Phoenix.Plug.store_in_session(admin)
        |> Plug.Conn.assign(:current_user, admin)

      {:ok, view, _html} = live(conn, ~p"/manage/settings/general")

      # Submit form with updated forecasting values
      view
      |> element("#settings-form")
      |> render_submit(%{
        "settings" => %{
          "forecast_lookback_days" => "30",
          "forecast_actual_weight" => "0.7",
          "forecast_planned_weight" => "0.3",
          "forecast_min_samples" => "15",
          "forecast_default_service_level" => "0.99",
          "forecast_default_horizon_days" => "21"
        }
      })

      assert render(view) =~ "Settings updated successfully"

      # Verify the values persisted
      {:ok, _view2, html} = live(conn, ~p"/manage/settings/general")

      assert html =~ "value=\"30\""
      assert html =~ "value=\"15\""
      assert html =~ "value=\"21\""
    end
  end
end
