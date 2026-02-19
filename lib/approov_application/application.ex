defmodule ApproovApplication.Application do
  use Application

  @impl true
  def start(_type, _args) do
    children = [
      {Phoenix.PubSub, name: ApproovApplication.PubSub},
      {ApproovApplication.ApproovState, []},
      ApproovApplicationWeb.Endpoint
    ]

    opts = [strategy: :one_for_one, name: ApproovApplication.Supervisor]
    Supervisor.start_link(children, opts)
  end

  @impl true
  def config_change(changed, _new, removed) do
    ApproovApplicationWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
