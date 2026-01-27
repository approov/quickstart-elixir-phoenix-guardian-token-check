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
      binding_headers: ["authorization"]
    },
    %{
      method: "GET",
      path: "/token-double-binding",
      action: :token_double_binding,
      binding_headers: ["authorization", "content-digest"]
    }
  ]

  def protected_routes do
    @protected_routes
  end

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

  @impl true
  def subject_for_token(_resource, _claims), do: {:ok, "approov"}

  @impl true
  def resource_from_claims(_claims), do: {:ok, :approov}

  def verify_request(conn, binding_headers) do
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

      timestamp ->
        expiration = DateTime.from_unix!(timestamp)

        case DateTime.compare(DateTime.utc_now(), expiration) do
          :lt -> :ok
          _ -> {:error, :approov_token_expired}
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
         :ok <- compare_pay_claim(pay_claim, expected_hash, binding_headers) do
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
    |> Base.url_encode64(padding: false)
  end

  defp compare_pay_claim(pay_claim, expected_hash, binding_headers) do
    case String.split(pay_claim, ":", parts: 2) do
      [^expected_hash] ->
        :ok

      [name, hash] ->
        expected_name = ApproovApplication.ProtectedRoutes.binding_name(binding_headers)

        if name == expected_name and hash == expected_hash do
          :ok
        else
          {:error, :token_binding_mismatch}
        end

      _ ->
        {:error, :token_binding_mismatch}
    end
  end
end

defmodule ApproovApplicationWeb.ApproovEnforcer do
  import Plug.Conn

  alias ApproovApplication.{ApproovState, ApproovTokenVerifier}

  def init(opts), do: opts

  def call(conn, _opts) do
    if ApproovState.enabled?() do
      binding_headers = conn.private[:approov_binding_headers] || []

      case ApproovTokenVerifier.verify_request(conn, binding_headers) do
        {:ok, _claims} -> conn
        {:error, _reason} -> reject(conn)
      end
    else
      conn
    end
  end

  defp reject(conn) do
    conn
    |> put_status(:unauthorized)
    |> Phoenix.Controller.json(%{error: "unauthorized"})
    |> halt()
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
      get(route.path, ApproovController, route.action,
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
