import Config

config :approov_application, ApproovApplicationWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 8080],
  server: true,
  code_reloader: false,
  debug_errors: true

config :logger, level: :info
