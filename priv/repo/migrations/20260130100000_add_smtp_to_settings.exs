defmodule Craftplan.Repo.Migrations.AddSmtpToSettings do
  @moduledoc false
  use Ecto.Migration

  def change do
    alter table(:settings) do
      add :smtp_host, :string
      add :smtp_port, :integer, default: 587
      add :smtp_username, :string
      add :smtp_password, :string
      add :smtp_tls, :string, default: "if_available"
    end
  end
end
