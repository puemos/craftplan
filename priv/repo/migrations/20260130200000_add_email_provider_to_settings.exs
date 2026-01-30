defmodule Craftplan.Repo.Migrations.AddEmailProviderToSettings do
  @moduledoc false
  use Ecto.Migration

  def change do
    alter table(:settings) do
      add :email_provider, :string, default: "smtp"
      add :email_api_key, :binary
      add :email_api_secret, :binary
      add :email_api_domain, :string
      add :email_api_region, :string, default: "us-east-1"
    end
  end
end
