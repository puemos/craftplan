import Config

# config/runtime.exs is executed for all environments, including
# during releases. It is executed after compilation and before the
# system starts, so it is typically used to load production configuration
# and secrets from environment variables or elsewhere. Do not define
# any compile-time configuration in here, as it won't be applied.
# The block below contains prod specific runtime configuration.

# ## Using releases
#
# If you use `mix release`, you need to explicitly enable the server
# by passing the PHX_SERVER=true when you start it:
#
#     PHX_SERVER=true bin/craftplan start
#
# Alternatively, you can use `mix phx.gen.release` to generate a `bin/server`
# script that automatically sets the env var above.
alias Swoosh.ApiClient.Finch

if System.get_env("PHX_SERVER") do
  config :craftplan, CraftplanWeb.Endpoint, server: true
end

if config_env() == :prod do
  database_url =
    System.get_env("DATABASE_URL") ||
      raise """
      environment variable DATABASE_URL is missing.
      For example: ecto://USER:PASS@HOST/DATABASE
      """

  maybe_ipv6 = if System.get_env("ECTO_IPV6") in ~w(true 1), do: [:inet6], else: []

  # The secret key base is used to sign/encrypt cookies and other secrets.
  # A default value is used in config/dev.exs and config/test.exs but you
  # want to use a different value for prod and you most likely don't want
  # to check this value into version control, so we use an environment
  # variable instead.
  secret_key_base =
    System.get_env("SECRET_KEY_BASE") ||
      raise """
      environment variable SECRET_KEY_BASE is missing.
      You can generate one by calling: mix phx.gen.secret
      """

  host = System.get_env("PHX_HOST") || "example.com"
  port = String.to_integer(System.get_env("PORT") || "4000")

  config :craftplan, Craftplan.Repo,
    # ssl: true,
    url: database_url,
    pool_size: String.to_integer(System.get_env("POOL_SIZE") || "10"),
    socket_options: maybe_ipv6

  config :craftplan, CraftplanWeb.Endpoint,
    url: [host: host, port: 443, scheme: "https"],
    http: [
      # Enable IPv6 and bind on all interfaces.
      # Set it to  {0, 0, 0, 0, 0, 0, 0, 1} for local network only access.
      # See the documentation on https://hexdocs.pm/bandit/Bandit.html#t:options/0
      # for details about using IPv6 vs IPv4 and loopback vs public addresses.
      ip: {0, 0, 0, 0, 0, 0, 0, 0},
      port: port
    ],
    secret_key_base: secret_key_base

  config :craftplan, :dns_cluster_query, System.get_env("DNS_CLUSTER_QUERY")

  if cors_origins = System.get_env("CORS_ORIGINS") do
    config :cors_plug, origin: String.split(cors_origins, ",", trim: true), methods: ["GET", "POST", "PATCH", "DELETE", "OPTIONS"]
  end

  config :craftplan,
    token_signing_secret:
      System.get_env("TOKEN_SIGNING_SECRET") ||
        raise("Missing environment variable `TOKEN_SIGNING_SECRET`!")

  # S3 / Waffle (product photo uploads)
  if System.get_env("AWS_ACCESS_KEY_ID") do
    config :ex_aws,
      json_codec: Jason,
      access_key_id: System.get_env("AWS_ACCESS_KEY_ID"),
      secret_access_key: System.get_env("AWS_SECRET_ACCESS_KEY"),
      region: System.get_env("AWS_REGION") || "us-east-1",
      s3: [
        scheme: "https://",
        host: System.get_env("AWS_S3_HOST") || "s3.amazonaws.com",
        region: System.get_env("AWS_REGION") || "us-east-1"
      ]

    config :waffle,
      storage: Waffle.Storage.S3,
      bucket: System.get_env("AWS_S3_BUCKET"),
      asset_host: System.get_env("AWS_ASSET_HOST")
  end

  # Cloak encryption vault
  cloak_key =
    System.get_env("CLOAK_KEY") ||
      raise "Missing environment variable CLOAK_KEY (32-byte key, base64-encoded)"

  # Email provider (env-var fallback — DB settings take precedence at boot)
  email_provider = System.get_env("EMAIL_PROVIDER")

  config :craftplan, Craftplan.Vault,
    ciphers: [
      default: {Cloak.Ciphers.AES.GCM, tag: "AES.GCM.V1", key: Base.decode64!(cloak_key)}
    ]

  cond do
    email_provider in ~w(sendgrid postmark brevo) ->
      adapter =
        case email_provider do
          "sendgrid" -> Swoosh.Adapters.SendGrid
          "postmark" -> Swoosh.Adapters.Postmark
          "brevo" -> Swoosh.Adapters.Brevo
        end

      config :craftplan, Craftplan.Mailer,
        adapter: adapter,
        api_key: System.get_env("EMAIL_API_KEY")

      config :swoosh, :api_client, Finch
      config :swoosh, :finch_name, Craftplan.Finch

    email_provider == "mailgun" ->
      config :craftplan, Craftplan.Mailer,
        adapter: Swoosh.Adapters.Mailgun,
        api_key: System.get_env("EMAIL_API_KEY"),
        domain: System.get_env("EMAIL_API_DOMAIN")

      config :swoosh, :api_client, Finch
      config :swoosh, :finch_name, Craftplan.Finch

    email_provider == "amazon_ses" ->
      config :craftplan, Craftplan.Mailer,
        adapter: Swoosh.Adapters.AmazonSES,
        access_key: System.get_env("EMAIL_API_KEY"),
        secret: System.get_env("EMAIL_API_SECRET"),
        region: System.get_env("EMAIL_API_REGION") || "us-east-1"

      config :swoosh, :api_client, Finch
      config :swoosh, :finch_name, Craftplan.Finch

    System.get_env("SMTP_HOST") != nil ->
      config :craftplan, Craftplan.Mailer,
        adapter: Swoosh.Adapters.SMTP,
        relay: System.get_env("SMTP_HOST"),
        port: String.to_integer(System.get_env("SMTP_PORT") || "587"),
        username: System.get_env("SMTP_USERNAME"),
        password: System.get_env("SMTP_PASSWORD"),
        tls: :always,
        auth: :always

      config :swoosh, :api_client, Finch
      config :swoosh, :finch_name, Craftplan.Finch

    true ->
      :ok
  end

  # ## SSL Support
  #
  # To get SSL working, you will need to add the `https` key
  # to your endpoint configuration:
  #
  #     config :craftplan, CraftplanWeb.Endpoint,
  #       https: [
  #         ...,
  #         port: 443,
  #         cipher_suite: :strong,
  #         keyfile: System.get_env("SOME_APP_SSL_KEY_PATH"),
  #         certfile: System.get_env("SOME_APP_SSL_CERT_PATH")
  #       ]
  #
  # The `cipher_suite` is set to `:strong` to support only the
  # latest and more secure SSL ciphers. This means old browsers
  # and clients may not be supported. You can set it to
  # `:compatible` for wider support.
  #
  # `:keyfile` and `:certfile` expect an absolute path to the key
  # and cert in disk or a relative path inside priv, for example
  # "priv/ssl/server.key". For all supported SSL configuration
  # options, see https://hexdocs.pm/plug/Plug.SSL.html#configure/1
  #
  # We also recommend setting `force_ssl` in your config/prod.exs,
  # ensuring no data is ever sent via http, always redirecting to https:
  #
  #     config :craftplan, CraftplanWeb.Endpoint,
  #       force_ssl: [hsts: true]
  #
  # Check `Plug.SSL` for all available options in `force_ssl`.

  # ## Configuring the mailer
  #
  # In production you need to configure the mailer to use a different adapter.
  # Also, you may need to configure the Swoosh API client of your choice if you
  # are not using SMTP. Here is an example of the configuration:
  #
  #     config :craftplan, Craftplan.Mailer,
  #       adapter: Swoosh.Adapters.Mailgun,
  #       api_key: System.get_env("MAILGUN_API_KEY"),
  #       domain: System.get_env("MAILGUN_DOMAIN")
  #
  # For this example you need include a HTTP client required by Swoosh API client.
  # Swoosh supports Hackney and Finch out of the box:
  #
  #     config :swoosh, :api_client, Swoosh.ApiClient.Hackney
  #
  # See https://hexdocs.pm/swoosh/Swoosh.html#module-installation for details.
end
