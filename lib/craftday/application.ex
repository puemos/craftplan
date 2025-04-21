defmodule Craftday.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      CraftdayWeb.Telemetry,
      Craftday.Repo,
      {DNSCluster, query: Application.get_env(:craftday, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: Craftday.PubSub},
      # Start the Finch HTTP client for sending emails
      {Finch, name: Craftday.Finch},
      # Start a worker by calling: Craftday.Worker.start_link(arg)
      # {Craftday.Worker, arg},
      # Start to serve requests, typically the last entry
      CraftdayWeb.Endpoint,
      {AshAuthentication.Supervisor, [otp_app: :craftday]}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Craftday.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    CraftdayWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
