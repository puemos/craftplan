defmodule Craftplan.Repo.Migrations.AddForecastingSettings do
  @moduledoc """
  Add forecasting configuration columns to the settings table.
  """
  use Ecto.Migration

  def change do
    alter table(:settings) do
      add :forecast_lookback_days, :integer, default: 42, null: false
      add :forecast_actual_weight, :decimal, default: 0.6, null: false
      add :forecast_planned_weight, :decimal, default: 0.4, null: false
      add :forecast_min_samples, :integer, default: 10, null: false
      add :forecast_default_service_level, :decimal, default: 0.95, null: false
      add :forecast_default_horizon_days, :integer, default: 14, null: false
    end
  end
end
