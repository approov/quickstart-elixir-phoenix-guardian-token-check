import Config

approov_secret =
  System.get_env("APPROOV_BASE64_SECRET") ||
    raise "Environment variable APPROOV_BASE64_SECRET is missing."

config :hello, HelloWeb.ApproovTokenPlug,
  allowed_algos: ["HS256"],
  secret_key: Base.decode64!(approov_secret)

# ## Using releases (Elixir v1.9+)
#
# If you are doing OTP releases, you need to instruct Phoenix
# to start each relevant endpoint:
#
config :hello, HelloWeb.Endpoint, server: true
#
# Then you can assemble a release by calling `mix release`.
# See `mix help release` for more information.
