defmodule Craftplan.Workers.Setup.Admin do
  @moduledoc false
  use Oban.Worker, queue: :default, max_attempts: 5, unique: [period: 30]

  alias Craftplan.Accounts

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"email" => email, "password" => password, "role" => role} = _args}) do
    Accounts.User
    |> Ash.Changeset.for_create(:register_with_password, %{
      email: email,
      password: password,
      password_confirmation: password,
      role: role
    })
    |> Ash.create(authorize?: false)
  rescue
    e ->
      {:error, e.errors}
  end

  @doc """
  Enqueues an Oban job to do start
  """
  @spec enqueue(Map.t(), :atom) :: {:ok, Job.t()} | {:error, Job.changeset()} | {:error, term()}
  def enqueue(args, :start) do
    args
    |> new(schedule_in: args.schedule_in)
    |> Oban.insert!()
  end

  def cancel(%{email: email}) do
    Oban.cancel_job(%Oban.Job{args: %{"email" => email}})
    %{email: email}
  end

  def cancel(%Oban.Job{} = job) do
    Oban.cancel_job(job)
    job
  end

  def cancel(email) do
    Oban.cancel_job(%Oban.Job{args: %{"email" => email}})
    %Oban.Job{args: %{"email" => email}}
  end
end
