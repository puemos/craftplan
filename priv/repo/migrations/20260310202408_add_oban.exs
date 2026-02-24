defmodule Craftplan.Repo.Migrations.AddOban do
  use Ecto.Migration

  def up, do: Oban.Migration.up(prefix: "oban")

  def down, do: Oban.Migration.down(version: 1, prefix: "oban")
end
