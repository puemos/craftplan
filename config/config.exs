# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

config :ash,
  include_embedded_source_by_default?: false,
  show_keysets_for_all_actions?: false,
  default_page_type: :keyset,
  policies: [no_filter_static_forbidden_reads?: false],
  known_types: [AshMoney.Types.Money],
  custom_types: [
    money: Money,
    currency: Craftplan.Types.Currency,
    unit: Craftplan.Types.Unit
  ]

# Configures the mailer
#
# By default it uses the "Local" adapter which stores the emails
# locally. You can see the emails in your browser, at "/dev/mailbox".
#
# For production it's recommended to configure a different adapter
# at the `config/runtime.exs`.
config :craftplan, Craftplan.Mailer, adapter: Swoosh.Adapters.Local

# Configures the endpoint
config :craftplan, CraftplanWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [html: CraftplanWeb.ErrorHTML, json: CraftplanWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: Craftplan.PubSub,
  live_view: [signing_salt: "vNk6HzXn"]

config :craftplan,
  ecto_repos: [Craftplan.Repo],
  generators: [timestamp_type: :utc_datetime],
  ash_domains: [
    Craftplan.Settings,
    Craftplan.CRM,
    Craftplan.Orders,
    Craftplan.Inventory,
    Craftplan.Catalog,
    Craftplan.Accounts
  ]

config :elixir, :time_zone_database, Tz.TimeZoneDatabase

# Configure esbuild (the version is required)
config :esbuild,
  version: "0.25.0",
  craftplan: [
    args: ~w(js/app.js --bundle --target=es2016 --outdir=../priv/static/assets),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
  ]

config :ex_cldr, default_backend: Craftplan.Cldr

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

config :spark,
  formatter: [
    remove_parens?: true,
    "Ash.Resource": [
      section_order: [
        :authentication,
        :tokens,
        :json_api,
        :graphql,
        :postgres,
        :resource,
        :code_interface,
        :actions,
        :policies,
        :pub_sub,
        :preparations,
        :changes,
        :validations,
        :multitenancy,
        :attributes,
        :relationships,
        :calculations,
        :aggregates,
        :identities
      ]
    ],
    "Ash.Domain": [
      section_order: [
        :json_api,
        :graphql,
        :resources,
        :policies,
        :authorization,
        :domain,
        :execution
      ]
    ]
  ]

config :tailwind,
  version: "4.1.3",
  craftplan: [
    args: ~w(
        --input=assets/css/app.css
        --output=priv/static/assets/app.css
      ),
    cd: Path.expand("..", __DIR__)
  ]

import_config "#{config_env()}.exs"
