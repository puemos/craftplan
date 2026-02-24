defmodule Craftplan.Oban do
  @moduledoc false
  use Oban, otp_app: :craftplan

  import Ecto.Query

  def running_jobs do
    conf = config()

    Oban.Job
    |> where([j], j.state == "executing")
    |> where([j], fragment("?[1]", j.attempted_by) == ^conf.node)
    |> conf.repo.all(prefix: conf.prefix)
    |> Enum.count()
  end

  def all_jobs do
    conf = config()

    Oban.Job
    |> where([j], fragment("?[1]", j.attempted_by) == ^conf.node)
    |> conf.repo.all(prefix: conf.prefix)
    |> Enum.count()
  end
end
