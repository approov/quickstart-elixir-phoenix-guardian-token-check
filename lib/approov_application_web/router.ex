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
