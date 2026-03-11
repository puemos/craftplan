defmodule Craftplan.Accounts.DefaultPasswordReset do
  @moduledoc false
  use Task

  def start_link(_arg) do
    Task.start_link(&poll/0)
  end

  def poll do
    receive do
    after
      60_000 ->
        reset()
        poll()
    end
  end

  defp reset do
    if "true" == System.get_env("DEMO") do
      case Enum.count(Craftplan.Accounts.list_admin_users!(authorize?: false)) do
        0 ->
          default_users = Application.fetch_env!(:craftplan, :default_users)

          if Enum.count(default_users) > 0 do
            Enum.each(default_users, fn {email, password, role} ->
              Craftplan.Workers.Setup.Admin.enqueue(
                %{id: "default", email: email, password: password, role: role, schedule_in: 15},
                :start
              )
            end)
          end

        _ ->
          default_users = Craftplan.Accounts.list_admin_users!(authorize?: false)

          Enum.each(default_users, fn user ->
            Craftplan.Workers.Setup.DemoUsers.enqueue(
              %{
                id: "default",
                email: user.email,
                role: user.role,
                schedule_in: 15
              },
              :start
            )
          end)
      end
    end
  end
end
