defmodule Microcraft.MixProject do
  use Mix.Project

  def project do
    [
      app: :microcraft,
      version: "0.1.0",
      elixir: "~> 1.14",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      consolidate_protocols: Mix.env() != :dev,
      aliases: aliases(),
      deps: deps()
    ]
  end

  # Configuration for the OTP application.
  #
  # Type `mix help compile.app` for more information.
  def application do
    [
      mod: {Microcraft.Application, []},
      extra_applications: [:logger, :runtime_tools]
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Specifies your project dependencies.
  #
  # Type `mix help deps` for examples and options.
  defp deps do
    [
      {:ash, "~> 3.0"},
      {:ash_admin, "~> 0.12"},
      {:ash_authentication, "~> 4.1"},
      {:ash_authentication_phoenix, "~> 2.0"},
      {:ash_money, "~> 0.1"},
      {:ash_phoenix, "~> 2.0"},
      {:ash_postgres, "~> 2.0"},
      {:bandit, "~> 1.5"},
      {:bcrypt_elixir, "~> 3.0"},
      {:dns_cluster, "~> 0.1.1"},
      {:ecto_sql, "~> 3.10"},
      {:esbuild, "~> 0.8", runtime: Mix.env() == :dev},
      {:ex_money_sql, "~> 1.0"},
      {:finch, "~> 0.13"},
      {:floki, ">= 0.30.0", only: :test},
      {:gettext, "~> 0.26"},
      {:heroicons,
       github: "tailwindlabs/heroicons", tag: "v2.1.1", sparse: "optimized", app: false, compile: false, depth: 1},
      {:igniter, "~> 0.5", only: [:dev, :test]},
      {:jason, "~> 1.2"},
      {:phoenix, "~> 1.7.18"},
      {:phoenix_ecto, "~> 4.5"},
      {:phoenix_html, "~> 4.1"},
      {:phoenix_live_dashboard, "~> 0.8.3"},
      {:phoenix_live_reload, "~> 1.2", only: :dev},
      {:phoenix_live_view, "~> 1.0.0"},
      {:phoenix_storybook, "~> 0.7.0"},
      {:picosat_elixir, "~> 0.2"},
      {:postgrex, ">= 0.0.0"},
      {:spark, "~> 2.2.36"},
      {:styler, "~> 1.2", only: [:dev, :test], runtime: false},
      {:swoosh, "~> 1.5"},
      {:tailwind, "~> 0.2", runtime: Mix.env() == :dev},
      {:tailwind_formatter, "~> 0.4.2", only: [:dev, :test], runtime: false},
      {:telemetry_metrics, "~> 1.0"},
      {:telemetry_poller, "~> 1.0"},
      {:tz, "~> 0.28"}
    ]
  end

  # Aliases are shortcuts or tasks specific to the current project.
  # For example, to install project dependencies and perform other setup tasks, run:
  #
  #     $ mix setup
  #
  # See the documentation for `Mix` for more info on aliases.
  defp aliases do
    [
      setup: ["deps.get", "ash.setup", "assets.setup", "assets.build", "run priv/repo/seeds.exs"],
      "ecto.setup": ["ecto.create", "ecto.migrate", "run priv/repo/seeds.exs"],
      "ecto.reset": ["ecto.drop", "ecto.setup"],
      test: ["ash.setup --quiet", "test"],
      "assets.setup": ["tailwind.install --if-missing", "esbuild.install --if-missing"],
      "assets.build": ["tailwind microcraft", "esbuild microcraft"],
      "assets.deploy": [
        "tailwind microcraft --minify",
        "tailwind storybook --minify",
        "esbuild microcraft --minify",
        "phx.digest"
      ]
    ]
  end
end
