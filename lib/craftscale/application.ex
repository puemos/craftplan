defmodule CraftScale.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      CraftScaleWeb.Telemetry,
      CraftScale.Repo,
      {DNSCluster, query: Application.get_env(:craftscale, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: CraftScale.PubSub},
      # Start the Finch HTTP client for sending emails
      {Finch, name: CraftScale.Finch},
      # Start a worker by calling: CraftScale.Worker.start_link(arg)
      # {CraftScale.Worker, arg},
      # Start to serve requests, typically the last entry
      CraftScaleWeb.Endpoint,
      {AshAuthentication.Supervisor, [otp_app: :craftscale]}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: CraftScale.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    CraftScaleWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
