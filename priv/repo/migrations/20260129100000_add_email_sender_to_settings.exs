defmodule Craftplan.Repo.Migrations.AddEmailSenderToSettings do
  use Ecto.Migration

  def change do
    alter table(:settings) do
      add :email_from_name, :string, null: false, default: "Craftplan"
      add :email_from_address, :string, null: false, default: "noreply@craftplan.app"
    end
  end
end
