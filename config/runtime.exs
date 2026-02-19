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
secret_env_name = "APPROOV_BASE64URL_SECRET"
secret_placeholder = "approov_base64url_secret_here"

approov_secret_b64url =
  case System.get_env(secret_env_name) do
    nil ->
      raise """
      Environment variable #{secret_env_name} is missing.
      Configure it in your local environment, for example:
      #{secret_env_name}=<approov_base64url_secret>
      """

    raw_value ->
      value = String.trim(raw_value)

      cond do
        value == "" ->
          raise """
          Environment variable #{secret_env_name} is empty.
          Configure it in your local environment, for example:
          #{secret_env_name}=<approov_base64url_secret>
          """

        value == secret_placeholder ->
          raise """
          Environment variable #{secret_env_name} is still using the placeholder value.
          Replace it with your real Approov secret.
          """

        true ->
          value
      end
  end

approov_secret =
  case Base.url_decode64(approov_secret_b64url, padding: false) do
    {:ok, decoded} when byte_size(decoded) > 0 ->
      decoded

    {:ok, _decoded} ->
      raise """
      Environment variable #{secret_env_name} decodes to an empty secret.
      Provide a valid non-empty Approov base64url secret.
      """

    :error ->
      # Fallback for padded/base64 secrets if needed.
      case Base.decode64(approov_secret_b64url) do
        {:ok, decoded} when byte_size(decoded) > 0 ->
          decoded

        {:ok, _decoded} ->
          raise """
          Environment variable #{secret_env_name} decodes to an empty secret.
          Provide a valid non-empty Approov base64url secret.
          """

        :error ->
          raise """
          Environment variable #{secret_env_name} is invalid.
          Provide a valid Approov base64url secret.
          """
      end
  end

config :approov_application, ApproovApplication.ApproovTokenVerifier,
  allowed_algos: ["HS256"],
  secret_key: approov_secret
