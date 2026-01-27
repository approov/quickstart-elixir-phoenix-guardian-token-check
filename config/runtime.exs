import Config

# Configure the HTTP listener from environment variables to support Docker and local runs.
port = String.to_integer(System.get_env("HTTP_PORT") || "8080")
raw_host = System.get_env("SERVER_HOSTNAME") || "0.0.0.0"

ip =
  case :inet.parse_address(String.to_charlist(raw_host)) do
    {:ok, parsed} -> parsed
    {:error, _} -> {0, 0, 0, 0}
  end

config :approov_application, ApproovApplicationWeb.Endpoint,
  http: [ip: ip, port: port],
  url: [host: raw_host, port: port],
  server: true

# Approov HS256 secret (base64url-encoded).
approov_secret_b64url =
  System.get_env("APPROOV_BASE64URL_SECRET") ||
    raise "Environment variable APPROOV_BASE64URL_SECRET is missing."

approov_secret =
  case Base.url_decode64(approov_secret_b64url, padding: false) do
    {:ok, decoded} ->
      decoded

    :error ->
      # Fallback for padded/base64 secrets if needed.
      Base.decode64!(approov_secret_b64url)
  end

config :approov_application, ApproovApplication.ApproovTokenVerifier,
  allowed_algos: ["HS256"],
  secret_key: approov_secret
