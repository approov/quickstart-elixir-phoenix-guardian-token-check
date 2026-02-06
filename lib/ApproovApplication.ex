defmodule ApproovApplicationWeb do
  def controller do
    quote do
      use Phoenix.Controller, formats: [:json]
      import Plug.Conn
    end
  end

  def router do
    quote do
      use Phoenix.Router
    end
  end

  def endpoint do
    quote do
      use Phoenix.Endpoint, otp_app: :approov_application
    end
  end

  defmacro __using__(which) when is_atom(which) do
    apply(__MODULE__, which, [])
  end
end

defmodule ApproovApplication.Application do
  use Application

  def start(_type, _args) do
    children = [
      {Phoenix.PubSub, name: ApproovApplication.PubSub},
      {ApproovApplication.ApproovState, []},
      ApproovApplicationWeb.Endpoint
    ]

    opts = [strategy: :one_for_one, name: ApproovApplication.Supervisor]
    Supervisor.start_link(children, opts)
  end

  def config_change(changed, _new, removed) do
    ApproovApplicationWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end

defmodule ApproovApplication.ApproovState do
  use Agent

  @name __MODULE__

  @spec start_link(any()) :: {:error, any()} | {:ok, pid()}
  def start_link(_opts) do
    Agent.start_link(fn -> %{enabled: true} end, name: @name)
  end

  def enabled? do
    Agent.get(@name, & &1.enabled)
  end

  def enable do
    Agent.update(@name, &Map.put(&1, :enabled, true))
  end

  def disable do
    Agent.update(@name, &Map.put(&1, :enabled, false))
  end
end

defmodule ApproovApplication.ProtectedRoutes do
  @protected_routes [
    %{method: "GET", path: "/token-check", action: :token_check, binding_headers: []},
    %{
      method: "GET",
      path: "/token-binding",
      action: :token_binding,
      binding_headers: ["Authorization"]
    },
    %{
      method: "GET",
      path: "/token-double-binding",
      action: :token_double_binding,
      binding_headers: ["Authorization", "SessionId"]
    }
  ]

  def protected_routes do
    @protected_routes
  end

  @spec requirements(any(), any()) :: any()
  def requirements(method, path) do
    Enum.find(@protected_routes, fn route ->
      route.method == method and route.path == path
    end)
  end

  def binding_name(headers) do
    headers
    |> Enum.map(&String.downcase/1)
    |> Enum.join("+")
  end
end

defmodule ApproovApplication.ApproovTokenVerifier do
  use Guardian, otp_app: :approov_application
  require Logger

  @approov_token_header "approov-token"
  @secret_placeholder "approov_base64url_secret_here"
  @secret_log_key {__MODULE__, :secret_issue_checked}

  @impl true
  def subject_for_token(_resource, _claims), do: {:ok, "approov"}

  @impl true
  def resource_from_claims(_claims), do: {:ok, :approov}

  def verify_request(conn, binding_headers) do
    log_secret_issue_once()

    with {:ok, token} <- fetch_approov_token(conn),
         {:ok, claims} <- decode_and_verify(token),
         :ok <- verify_expiration(claims),
         :ok <- verify_binding(conn, claims, binding_headers) do
      {:ok, claims}
    else
      {:error, reason} ->
        Logger.debug("Approov verification failed: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp fetch_approov_token(conn) do
    case Plug.Conn.get_req_header(conn, @approov_token_header) do
      [token | _] -> {:ok, token}
      _ -> {:error, :missing_approov_token}
    end
  end

  defp verify_expiration(%{"exp" => exp}) do
    exp_unix =
      cond do
        is_integer(exp) ->
          exp

        is_float(exp) ->
          trunc(exp)

        is_binary(exp) ->
          case Integer.parse(exp) do
            {value, _} -> value
            :error -> nil
          end

        true ->
          nil
      end

    case exp_unix do
      nil ->
        {:error, :invalid_exp_claim}

      timestamp when is_integer(timestamp) ->
        now = System.system_time(:second)

        if timestamp > now do
          :ok
        else
          {:error, :approov_token_expired}
        end
    end
  end

  defp verify_expiration(_claims), do: {:error, :missing_exp_claim}

  defp verify_binding(_conn, _claims, binding_headers)
       when binding_headers in [nil, []] do
    :ok
  end

  defp verify_binding(conn, %{"pay" => pay_claim}, binding_headers) do
    with {:ok, binding_value} <- binding_value(conn, binding_headers),
         expected_hash <- binding_hash(binding_value),
         :ok <- compare_pay_claim(pay_claim, expected_hash) do
      :ok
    else
      {:error, reason} -> {:error, reason}
    end
  end

  defp verify_binding(_conn, _claims, _binding_headers), do: {:error, :missing_pay_claim}

  defp binding_value(conn, headers) do
    headers
    |> Enum.map(&String.downcase/1)
    |> Enum.reduce_while([], fn header, acc ->
      case Plug.Conn.get_req_header(conn, header) do
        [value | _] -> {:cont, [value | acc]}
        _ -> {:halt, {:error, {:missing_binding_header, header}}}
      end
    end)
    |> case do
      {:error, _} = error -> error
      values -> {:ok, values |> Enum.reverse() |> Enum.join("")}
    end
  end

  defp binding_hash(value) do
    :crypto.hash(:sha256, value)
    |> Base.encode64()
  end

  defp compare_pay_claim(pay_claim, expected_hash) do
    pay_claim = String.trim(pay_claim)

    if Plug.Crypto.secure_compare(pay_claim, expected_hash) do
      :ok
    else
      {:error, :token_binding_mismatch}
    end
  end

  defp log_secret_issue_once do
    case :persistent_term.get(@secret_log_key, :unchecked) do
      :unchecked ->
        case secret_issue() do
          nil ->
            :persistent_term.put(@secret_log_key, :ok)

          message ->
            Logger.error(message)
            :persistent_term.put(@secret_log_key, :invalid)
        end

      _ ->
        :ok
    end
  end

  defp secret_issue do
    value = System.get_env("APPROOV_BASE64URL_SECRET")

    cond do
      value in [nil, ""] ->
        "Required secret is not set"

      value == @secret_placeholder ->
        "Required secret is not set"

      valid_base64url?(value) ->
        nil

      valid_base64?(value) ->
        nil

      true ->
        "Required secret is invalid"
    end
  end

  defp valid_base64url?(value) do
    case Base.url_decode64(value, padding: false) do
      {:ok, _} -> true
      :error -> false
    end
  end

  defp valid_base64?(value) do
    case Base.decode64(value) do
      {:ok, _} -> true
      :error -> false
    end
  end
end

defmodule ApproovApplicationWeb.ApproovEnforcer do
  import Plug.Conn
  require Logger

  alias ApproovApplication.{ApproovState, ApproovTokenVerifier}

  def init(opts), do: opts

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

  defp reject(conn, reason) do
    conn
    |> assign(:approov_failure, reason)
    |> put_status(:unauthorized)
    |> Phoenix.Controller.json(%{error: "unauthorized"})
    |> halt()
  end

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

  defp required_headers(binding_headers) do
    ["Approov-Token" | binding_headers]
    |> Enum.map(&canonical_header/1)
    |> Enum.uniq()
  end

  defp canonical_header(header) when is_binary(header) do
    case String.downcase(header) do
      "approov-token" -> "Approov-Token"
      "authorization" -> "Authorization"
      "sessionid" -> "SessionId"
      other -> titleize_header(other)
    end
  end

  defp canonical_header(header), do: header

  defp titleize_header(header) do
    header
    |> String.split("-")
    |> Enum.map(&String.capitalize/1)
    |> Enum.join("-")
  end

  defp ip_string(nil), do: nil

  defp ip_string(ip) do
    ip
    |> :inet.ntoa()
    |> to_string()
  end
end

defmodule ApproovApplicationWeb.ApproovController do
  use ApproovApplicationWeb, :controller

  alias ApproovApplication.ApproovState

  def unprotected(conn, _params) do
    json(conn, %{message: "unprotected"})
  end

  def token_check(conn, _params) do
    json(conn, %{message: "token-check ok"})
  end

  def token_binding(conn, _params) do
    json(conn, %{message: "token-binding ok"})
  end

  def token_double_binding(conn, _params) do
    json(conn, %{message: "token-double-binding ok"})
  end

  def approov_state(conn, _params) do
    json(conn, %{approovEnabled: ApproovState.enabled?()})
  end

  def enable(conn, _params) do
    ApproovState.enable()
    json(conn, %{approovEnabled: true})
  end

  def disable(conn, _params) do
    ApproovState.disable()
    json(conn, %{approovEnabled: false})
  end
end

defmodule ApproovApplicationWeb.ErrorView do
  def render(_template, _assigns) do
    %{error: "error"}
  end
end

defmodule ApproovApplicationWeb.Router do
  use ApproovApplicationWeb, :router

  pipeline :api do
    plug(:accepts, ["json"])
  end

  pipeline :approov do
    plug(ApproovApplicationWeb.ApproovEnforcer)
  end

  scope "/", ApproovApplicationWeb do
    pipe_through(:api)

    get("/unprotected", ApproovController, :unprotected)
    get("/approov-state", ApproovController, :approov_state)
    post("/approov/enable", ApproovController, :enable)
    post("/approov/disable", ApproovController, :disable)
  end

  scope "/", ApproovApplicationWeb do
    pipe_through([:api, :approov])

    for route <- ApproovApplication.ProtectedRoutes.protected_routes() do
      verb = String.downcase(route.method) |> String.to_atom()
      match(verb, route.path, ApproovController, route.action,
        private: %{approov_binding_headers: route.binding_headers}
      )
    end
  end
end

defmodule ApproovApplicationWeb.Endpoint do
  use ApproovApplicationWeb, :endpoint

  plug(Plug.RequestId)

  plug(Plug.Parsers,
    parsers: [:urlencoded, :multipart, :json],
    pass: ["*/*"],
    json_decoder: Jason
  )

  plug(Plug.MethodOverride)
  plug(Plug.Head)
  plug(ApproovApplicationWeb.Router)
end
