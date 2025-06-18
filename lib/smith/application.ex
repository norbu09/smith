defmodule Smith.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      SmithWeb.Telemetry,
      Smith.Repo,
      {DNSCluster, query: Application.get_env(:smith, :dns_cluster_query) || :ignore},
      {Oban,
       AshOban.config(
         Application.fetch_env!(:smith, :ash_domains),
         Application.fetch_env!(:smith, Oban)
       )},
      {Phoenix.PubSub, name: Smith.PubSub},
      # Start a worker by calling: Smith.Worker.start_link(arg)
      # {Smith.Worker, arg},
      # Start to serve requests, typically the last entry
      SmithWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Smith.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    SmithWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
