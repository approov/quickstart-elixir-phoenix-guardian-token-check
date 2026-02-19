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
