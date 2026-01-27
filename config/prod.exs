import Config

config :approov_application, ApproovApplicationWeb.Endpoint,
  http: [ip: {0, 0, 0, 0}, port: 8080],
  server: true
