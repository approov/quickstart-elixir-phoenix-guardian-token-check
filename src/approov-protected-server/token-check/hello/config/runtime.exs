import Config

approov_secret =
  System.get_env("APPROOV_BASE64_SECRET") ||
    raise "Environment variable APPROOV_BASE64_SECRET is missing."

IO.inspect(approov_secret)
config :hello, HelloWeb.ApproovTokenPlug,
  allowed_algos: ["HS256"],
  issuer: "approov",
  secret_key: Base.decode64!(approov_secret)
