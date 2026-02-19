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
