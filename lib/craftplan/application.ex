defmodule Craftplan.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      CraftplanWeb.Telemetry,
      Craftplan.Vault,
      Craftplan.Repo,
      {DNSCluster, query: Application.get_env(:craftplan, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: Craftplan.PubSub},
      # Start the Finch HTTP client for sending emails
      {Finch, name: Craftplan.Finch},
      # Start a worker by calling: Craftplan.Worker.start_link(arg)
      # {Craftplan.Worker, arg},
      # Start to serve requests, typically the last entry
      CraftplanWeb.Endpoint,
      {AshAuthentication.Supervisor, [otp_app: :craftplan]}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Craftplan.Supervisor]
    result = Supervisor.start_link(children, opts)

    apply_smtp_from_settings()

    result
  end

  defp apply_smtp_from_settings do
    case Craftplan.Settings.get_settings() do
      {:ok, settings} -> Craftplan.Mailer.apply_settings(settings)
      _ -> :ok
    end
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    CraftplanWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
