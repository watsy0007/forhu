defmodule Forhu.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      # Start the Telemetry supervisor
      ForhuWeb.Telemetry,
      # Start the PubSub system
      {Phoenix.PubSub, name: Forhu.PubSub},
      {Task.Supervisor, name: Forhu.TaskSupervisor},
      # Start the Endpoint (http/https)
      ForhuWeb.Endpoint
      # Start a worker by calling: Forhu.Worker.start_link(arg)
      # {Forhu.Worker, arg}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Forhu.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    ForhuWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
