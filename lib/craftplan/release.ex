defmodule Craftplan.Release do
  @moduledoc """
  Release tasks that can be run without Mix (inside OTP releases).

  Usage:

      bin/craftplan eval "Craftplan.Release.migrate"
  """

  @app :craftplan

  def migrate do
    load_app()

    for repo <- repos() do
      {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :up, all: true))
    end
  end

  def reset do
    start_app_without_server()

    for repo <- repos() do
      repo.query!("DROP SCHEMA public CASCADE")
      repo.query!("CREATE SCHEMA public")
    end

    Ecto.Migrator.with_repo(Craftplan.Repo, &Ecto.Migrator.run(&1, :up, all: true))
    seed()
  end

  def seed do
    start_app_without_server()
    seeds_file = Application.app_dir(@app, "priv/repo/seeds.exs")
    Code.eval_file(seeds_file)
  end

  def rollback(repo, version) do
    load_app()
    {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :down, to: version))
  end

  defp start_app_without_server do
    System.delete_env("PHX_SERVER")
    {:ok, _} = Application.ensure_all_started(@app)
  end

  defp repos do
    Application.fetch_env!(@app, :ecto_repos)
  end

  defp load_app do
    Application.load(@app)
  end
end
