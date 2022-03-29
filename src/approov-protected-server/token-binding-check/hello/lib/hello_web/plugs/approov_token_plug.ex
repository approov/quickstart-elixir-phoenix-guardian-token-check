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
         :ok <- _verify_expiration(approov_token_claims) do
      {:ok, conn, approov_token_claims}
    else
      [] ->
        # You may want to modify/remove logging here
        Logger.debug("Missing the Approov token header!")
        {:error, conn}

      {:error, reason} when is_atom(reason) ->
        # You may want to modify/remove logging here
        Logger.debug(Atom.to_string(reason))
        {:error, conn}

      {:error, %ArgumentError{} = error} ->
        # Comment out for debug
        # IO.inspect(error, label: "Argument Error")

        # You may want to modify/remove logging here
        Logger.debug(
          "Approov token may be an invalid JWT token, e.g: with an invalid number of segments!"
        )
        {:error, conn}

      {:error, error} ->
        # Comment out for debug
        # IO.inspect(error, label: "Generic Error")

        # You may want to modify/remove logging here
        Logger.debug("Approov token verification failed with an unexpected reason for the error!")
        {:error, conn}
    end
  end

  defp _verify_expiration(%{"exp" => timestamp}) do
    datetime = _timestamp_to_datetime(timestamp)
    now = DateTime.utc_now()

    case DateTime.compare(now, datetime) do
      :lt ->
        :ok

      _ ->
        {:error, :approov_token_expired}
    end
  end

  defp _verify_expiration(_claims) do
    {:error, :missing_exp_claim}
  end

  defp _timestamp_to_datetime(timestamp) when is_integer(timestamp) do
    DateTime.from_unix!(timestamp)
  end

  defp _timestamp_to_datetime(timestamp) when is_float(timestamp) do
    # @link https://github.com/ueberauth/guardian/issues/699
    #
    # iex> Integer.parse "1555083349.3777623"
    # {1555083349, ".3777623"}
    {timestamp, _decimals} = Integer.parse("#{timestamp}")
    DateTime.from_unix!(timestamp)
  end

  defp _verify_approov_token_binding(
         conn,
         %{"pay" => token_binding_claim} = _approov_token_claims
       ) do
    # We use the Authorization token, but feel free to use another header in
    # the request. Bear in mind that it needs to be the same header used in the
    # mobile app to bind the request with the Approov token.
    with [token_binding_header | _] <- Plug.Conn.get_req_header(conn, "authorization"),
      true <- _is_token_binding_valid(token_binding_header, token_binding_claim)
    do
      {:ok, conn}
    else
      [] ->
        # You may want to modify/remove logging here
        Logger.debug("Missing the Approov token binding header!")
        {:error, conn}

      {:error, _error} ->
        # Comment out for debug
        # IO.inspect(error, label: "Token Binding Error")

        # You may want to modify/remove logging here
        Logger.debug(
          "Approov token binding verification failed with an unexpected reason for the error!"
        )
        {:error, conn}

      false ->
        # You may want to modify/remove logging here
        Logger.debug("Token binding header not matching with the Approov token.")
        {:error, conn}
    end
  end

  defp _verify_approov_token_binding(conn, _approov_token_claims) do
    # You may want to modify/remove logging here
    Logger.debug("Missing the `pay` claim in the Approov token.")
    {:error, conn}
  end

  defp _is_token_binding_valid(token_binding_header, token_binding_claim) do
    # We need to hash and base64 encode the token binding header, because that's
    # how it was included in the Approov token on the mobile app.
    token_binding_header_encoded =
      :crypto.hash(:sha256, token_binding_header)
      |> Base.encode64()

    token_binding_claim === token_binding_header_encoded
  end

  defp _halt_connection(conn) do
    conn
    |> Plug.Conn.put_status(401)
    |> Phoenix.Controller.json(%{})
    |> Plug.Conn.halt()
  end
end
