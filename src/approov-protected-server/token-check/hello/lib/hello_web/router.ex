defmodule HelloWeb.Router do
  use HelloWeb, :router

  pipeline :api do
    plug :accepts, ["json"]
  end

  pipeline :approov do
    plug HelloWeb.ApproovTokenPlug
  end

  scope "/", HelloWeb do
    pipe_through :api
    pipe_through :approov

    get "/", HelloController, :show
  end
end
