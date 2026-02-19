defmodule ApproovApplication.ProtectedRoutes do
  @moduledoc false

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

  @spec protected_routes() :: list(map())
  def protected_routes do
    @protected_routes
  end

  @spec requirements(String.t(), String.t()) :: map() | nil
  def requirements(method, path) do
    Enum.find(@protected_routes, fn route ->
      route.method == method and route.path == path
    end)
  end
end
