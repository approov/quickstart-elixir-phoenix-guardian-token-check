defmodule ApproovApplicationWeb.ApproovEnforcer do
  import Plug.Conn
  require Logger

  alias ApproovApplication.{ApproovState, ApproovTokenVerifier}

  @spec init(keyword()) :: keyword()
  def init(opts), do: opts

  @spec call(Plug.Conn.t(), keyword()) :: Plug.Conn.t()
  def call(conn, _opts) do
    binding_headers = conn.private[:approov_binding_headers] || []
    approov_enabled = ApproovState.enabled?()

    conn = register_request_logging(conn, binding_headers, approov_enabled)

    if approov_enabled do
      case ApproovTokenVerifier.verify_request(conn, binding_headers) do
        {:ok, _claims} -> conn
        {:error, reason} -> reject(conn, reason)
      end
    else
      conn
    end
  end

  @spec reject(Plug.Conn.t(), any()) :: Plug.Conn.t()
  defp reject(conn, reason) do
    conn
    |> assign(:approov_failure, reason)
    |> put_status(:unauthorized)
    |> Phoenix.Controller.json(%{error: "unauthorized"})
    |> halt()
  end

  @spec register_request_logging(Plug.Conn.t(), [String.t()], boolean()) :: Plug.Conn.t()
  defp register_request_logging(conn, binding_headers, approov_enabled) do
    token_binding_enabled = binding_headers != []
    required_headers = required_headers(binding_headers)

    register_before_send(conn, fn conn ->
      if conn.status in [200, 401] do
        payload = %{
          summary: request_summary(conn, approov_enabled),
          method: conn.method,
          path: conn.request_path,
          status: conn.status,
          ip: ip_string(conn.remote_ip),
          port: conn.port,
          approovEnabled: approov_enabled,
          tokenBindingEnabled: token_binding_enabled,
          required_headers: required_headers
        }

        Logger.info("http.request.completed " <> Jason.encode!(payload))
      end

      conn
    end)
  end

  @spec request_summary(Plug.Conn.t(), boolean()) :: String.t()
  defp request_summary(conn, approov_enabled) do
    case conn.status do
      401 ->
        reason = Map.get(conn.assigns, :approov_failure)
        "approov_failed:" <> failure_reason(reason)

      200 ->
        if approov_enabled, do: "approov_ok", else: "approov_disabled"

      _ ->
        "http_request"
    end
  end

  defp failure_reason({:missing_binding_header, _header}), do: "missing_binding_header"
  defp failure_reason(reason) when is_atom(reason), do: Atom.to_string(reason)
  defp failure_reason(_reason), do: "token_verification_failed"

  @spec required_headers([String.t()]) :: [String.t()]
  defp required_headers(binding_headers) do
    ["Approov-Token" | binding_headers]
    |> Enum.map(&canonical_header/1)
    |> Enum.uniq()
  end

  @spec canonical_header(String.t()) :: String.t()
  defp canonical_header(header) when is_binary(header) do
    case String.downcase(header) do
      "approov-token" -> "Approov-Token"
      "authorization" -> "Authorization"
      "sessionid" -> "SessionId"
      other -> titleize_header(other)
    end
  end

  defp canonical_header(header), do: header

  @spec titleize_header(String.t()) :: String.t()
  defp titleize_header(header) do
    header
    |> String.split("-")
    |> Enum.map(&String.capitalize/1)
    |> Enum.join("-")
  end

  @spec ip_string(:inet.ip_address()) :: String.t()
  defp ip_string(ip) do
    ip
    |> :inet.ntoa()
    |> to_string()
  end
end
