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
