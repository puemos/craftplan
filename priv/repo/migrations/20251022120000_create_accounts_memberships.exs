defmodule Craftplan.Repo.Migrations.CreateAccountsMemberships do
  use Ecto.Migration

  def up do
    create table(:accounts_memberships, primary_key: false) do
      add :id, :uuid, primary_key: true, null: false, default: fragment("gen_random_uuid()")

      add :organization_id, references(:organizations, type: :uuid, on_delete: :delete_all),
        null: false

      add :user_id, references(:accounts_users, type: :uuid, on_delete: :delete_all), null: false
      add :role, :text, null: false, default: "owner"
      add :status, :text, null: false, default: "active"

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:accounts_memberships, [:organization_id, :user_id],
             name: "accounts_memberships_unique_org_user_index"
           )

    create index(:accounts_memberships, [:user_id])
  end

  def down do
    drop_if_exists index(:accounts_memberships, [:user_id])

    drop_if_exists unique_index(:accounts_memberships, [:organization_id, :user_id],
                     name: "accounts_memberships_unique_org_user_index"
                   )

    drop_if_exists table(:accounts_memberships)
  end
end
