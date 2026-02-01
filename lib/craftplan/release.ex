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
    load_app()
    Application.ensure_all_started(:postgrex)

    # Parse the DATABASE_URL and open a raw Postgrex connection to
    # drop/recreate the schema. This avoids pool disconnection issues
    # since DROP SCHEMA CASCADE terminates all other connections.
    db_url = System.get_env("DATABASE_URL") || raise "DATABASE_URL not set"
    uri = URI.parse(db_url)
    [username, password] = String.split(uri.userinfo || "postgres:", ":")

    {:ok, conn} =
      Postgrex.start_link(
        hostname: uri.host,
        port: uri.port || 5432,
        username: username,
        password: password,
        database: String.trim_leading(uri.path, "/"),
        ssl: false,
        socket_options: [:inet6]
      )

    Postgrex.query!(conn, "DROP SCHEMA public CASCADE", [])
    Postgrex.query!(conn, "CREATE SCHEMA public", [])
    GenServer.stop(conn)

    migrate()
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
