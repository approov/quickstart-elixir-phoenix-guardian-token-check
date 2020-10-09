import Config

approov_secret =
  System.get_env("APPROOV_BASE64_SECRET") ||
    raise "Environment variable APPROOV_BASE64_SECRET is missing."

config :hello, HelloWeb.ApproovTokenPlug,
  allowed_algos: ["HS256"],
  secret_key: Base.decode64!(approov_secret)
