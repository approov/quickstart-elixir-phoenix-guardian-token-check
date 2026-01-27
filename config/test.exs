import Config

config :approov_application, ApproovApplicationWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 8081],
  server: false
