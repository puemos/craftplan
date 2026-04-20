defmodule Craftplan.Repo.Seeds.AddAccounts do
  @moduledoc false
  use Craftplan.Seed

  require Ash.Query

  envs([:dev, :prod])

  @params [{"staff@test.com", :staff}, {"customer@test.com", :customer}]

  def up(_repo, _) do
    Enum.each(@params, fn {email, role} ->
      Craftplan.Accounts.User
      |> Ash.Changeset.for_create(:register_with_password, %{
        email: email,
        password: "Aa123123123123",
        password_confirmation: "Aa123123123123",
        role: role
      })
      |> Ash.create(
        context: %{
          strategy: AshAuthentication.Strategy.Password,
          private: %{ash_authentication?: true}
        }
      )
    end)
  end
end
