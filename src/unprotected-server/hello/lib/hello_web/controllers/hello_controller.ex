defmodule HelloWeb.HelloController do
  use HelloWeb, :controller

  def show(conn, _params) do
    json(conn, %{message: "Hello, World!"})
  end
end
