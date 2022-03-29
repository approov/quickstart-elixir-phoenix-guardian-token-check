defmodule HelloWeb.ApproovTokenPlug do
  require Logger

  ##############################################################################
  # Adhere to the Phoenix Module Plugs specification by implementing:
  #   * init/1
  #   * call/2
  #
  # @link https://hexdocs.pm/phoenix/plug.html#module-plugs
  ##############################################################################

  def init(options), do: options

  def call(conn, _options) do
    with {:ok, conn, approov_token_claims} <- _verify_approov_token(conn),
         {:ok, conn} <- _verify_approov_token_binding(conn, approov_token_claims) do
      conn
    else
      {:error, conn} ->
        conn |> _halt_connection()
    end
  end

  ##############################################################################
  # Inject Guardian functions and implement the required behaviour callbacks:
  #   * subject_for_token/2
  #   * resource_from_claims/2
  #
  # The required behaviour functions are not necessary in the context of
  # checking the Approov token, but required to be implemented in order to use
  # Guardian.
  ##############################################################################

  use Guardian, otp_app: :hello

  @impl true
  def subject_for_token(user, _claims), do: {:ok, to_string(user.id)}

  @impl true
  def resource_from_claims(claims), do: {:ok, claims["sub"]}

  defp _verify_approov_token(conn) do
    with [approov_token | _] <- Plug.Conn.get_req_header(conn, "approov-token"),
         {:ok, approov_token_claims} <- decode_and_verify(approov_token),
         true <- _has_expiration_claim(approov_token_claims) do
      {:ok, conn, approov_token_claims}
    else
      [] ->
        # You may want to add some logging here
        Logger.debug("Missing the Approov token header!")
        {:error, conn}

      {:error, reason} when is_atom(reason) ->
        # You may want to add some logging here
        Logger.debug(Atom.to_string(reason))
        {:error, conn}

      {:error, %ArgumentError{} = error} ->
        IO.inspect(error, label: "Argument Error:")
        # You may want to add some logging here
        Logger.debug(
          "Approov token may be an invalid JWT token, e.g: with an invalid number of segments!"
        )
        {:error, conn}

      {:error, error} ->
        IO.inspect(error, label: "Other Error:")

        # You may want to add some logging here
        Logger.debug("Approov token verification failed with an unexpected reason for the error!")
        {:error, conn}

      false ->
        # You may want to add some logging here
        Logger.debug("Missing `exp` claim in a valid signed Approov token.")
        {:error, conn}
    end
  end

  defp _verify_approov_token_binding(
         conn,
         %{"pay" => token_binding_claim} = _approov_token_claims
       ) do
    # We use the Authorization token, but feel free to use another header in
    # the request. Bear in mind that it needs to be the same header used in the
    # mobile app to bind the request with the Approov token.
    with [token_binding_header | _] <- Plug.Conn.get_req_header(conn, "authorization"),

         # We need to hash and base64 encode the token binding header, because that's
         # how it was included in the Approov token on the mobile app.
         token_binding_header_encoded <-
           :crypto.hash(:sha256, token_binding_header) |> Base.encode64(),
         true <- token_binding_claim === token_binding_header_encoded do
      {:ok, conn}
    else
      [] ->
        # You may want to add some logging here
        # Logger.debug("Missing the Approov token binding header!")
        {:error, conn}

      {:error, error} ->
        IO.inspect(error, label: "Token Binding Error:")

        # You may want to add some logging here
        Logger.debug(
          "Approov token binding verification failed with an unexpected reason for the error!"
        )
        {:error, conn}

      false ->
        # You may want to add some logging here
        # Logger.debug("Token binding header not matching with the Approov token.")
        {:error, conn}
    end
  end

  # Note that the `pay` claim will, under normal circumstances, be present,
  # but if the Approov failover system is enabled, then no claim will be
  # present, and in this case you want to return true, otherwise you will not
  # be able to benefit from the redundancy afforded by the failover system.
  defp _verify_approov_token_binding(conn, _approov_token_claims) do
    # You may want to add some logging here
    # Logger.debug("Missing the `pay` claim in the Approov token.")
    {:ok, conn}
  end

  defp _has_expiration_claim(%{"exp" => _exp}), do: true
  defp _has_expiration_claim(_approov_token_claims), do: false

  defp _halt_connection(conn) do
    conn
    |> Plug.Conn.put_status(401)
    |> Phoenix.Controller.json(%{})
    |> Plug.Conn.halt()
  end
end
