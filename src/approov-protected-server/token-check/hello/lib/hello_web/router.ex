defmodule HelloWeb.Router do
  use HelloWeb, :router

  pipeline :api do
    plug :accepts, ["json"]

    # Ideally you will not want to add any other Plug before the Approov Token
    # check to protect your server from wasting resources in processing requests
    # not having a valid Approov token. This increases availability for your
    # users during peak time or in the event of a DoS attack(We all know the
    # BEAM design allows to cope very well with this scenarios, but best to play
    # in the safe side).
    plug HelloWeb.ApproovTokenPlug
  end

  scope "/", HelloWeb do
    pipe_through :api

    get "/", HelloController, :show
  end
end
