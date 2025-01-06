import Config

config :ash, disable_async?: true

# In test we don't send emails
# to provide built-in test partitioning in CI environment.
# Configure your database
# Run `mix help test` for more information.
#
# The MIX_TEST_PARTITION environment variable can be used

config :craftscale, CraftScale.Mailer, adapter: Swoosh.Adapters.Test

config :craftscale, CraftScale.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "craftscale_test#{System.get_env("MIX_TEST_PARTITION")}",
  pool: Ecto.Adapters.SQL.Sandbox,
  # We don't run a server during test. If one is required,
  # you can enable the server option below.
  pool_size: System.schedulers_online() * 2

config :craftscale, CraftScaleWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "IPun5u1kwt9+i88jrjN5mJzlM1E6BJE68ZGIG0169TQxjb6GAKdivKt5SWLHYP26",
  server: false

config :craftscale, token_signing_secret: "/7GrJHgmCNYkIsiOKCsK28JJckAxvMLD"

# Print only warnings and errors during test
config :logger, level: :warning

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime

# Enable helpful, but potentially expensive runtime checks
config :phoenix_live_view,
  enable_expensive_runtime_checks: true

# Disable swoosh api client as it is only required for production adapters
config :swoosh, :api_client, false
