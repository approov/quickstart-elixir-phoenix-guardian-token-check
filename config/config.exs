import Config

config :approov_application,
  ecto_repos: []

config :approov_application, ApproovApplicationWeb.Endpoint,
  url: [host: "localhost"],
  render_errors: [formats: [json: ApproovApplicationWeb.ErrorView], layout: false],
  pubsub_server: ApproovApplication.PubSub

config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

config :phoenix, :json_library, Jason

import_config "#{config_env()}.exs"
