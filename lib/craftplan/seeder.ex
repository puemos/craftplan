defmodule Craftplan.Release.Seeder do
  @moduledoc false
  import Ecto
  import Ecto.Migrator, only: [migrations_path: 2, with_repo: 2]

  @app :craftplan

  def seed(opts \\ [], seeder \\ &PhilColumns.Seeder.run/4) do
    load_app()

    repos = [Craftplan.Repo]

    # set env with current_env/0 overwriting provided arg
    opts = Keyword.put(opts, :env, current_env())
    opts = Keyword.put(opts, :tags, [])

    opts =
      if opts[:to] || opts[:step] || opts[:all],
        do: opts,
        else: Keyword.put(opts, :all, true)

    opts =
      if opts[:log],
        do: opts,
        else: Keyword.put(opts, :log, :info)

    opts =
      if opts[:quiet],
        do: Keyword.put(opts, :log, false),
        else: opts

    for repo <- repos() do
      {:ok, _, _} = with_repo(repo, &seeder.(&1, migrations_path(&1, "seeds"), :up, opts))
    end
  end

  defp current_env do
    case Application.fetch_env(@app, :env) do
      :error -> :dev
      {:ok, data} -> data
    end
  end

  defp repos do
    Application.fetch_env!(@app, :ecto_repos)
  end

  defp load_app do
    Application.load(@app)
  end
end
