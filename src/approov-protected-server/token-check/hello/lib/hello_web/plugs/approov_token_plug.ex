defmodule HelloWeb.ApproovTokenPlug do
  require Logger

  ######################################################################
  # Adhere to the Phoenix Module Plugs specification by implementing:
  #   * init/1
  #   * call/2
  #
  # @link https://hexdocs.pm/phoenix/plug.html#module-plugs
  ######################################################################

  def init(options), do: options

  def call(conn, _options) do
    with {:ok, conn, _approov_token_claims} <- _verify_approov_token(conn)
      do
        conn
      else
        {:error, conn} ->
          conn |> _halt_connection()
    end
  end


  #############################################################################
  # Inject Guardian functions and implement the required behaviour callbacks:
  #   * subject_for_token/2
  #   * resource_from_claims/2
  #
  # The required behaviour functions are not necessary in the context of
  # checking the Approov token, but required to be implemented in order to use
  # Guardian.
  #############################################################################

  use Guardian, otp_app: :hello

  @impl true
  def subject_for_token(user, _claims), do: {:ok, to_string(user.id)}

  @impl true
  def resource_from_claims(claims), do: {:ok, claims["sub"]}

  defp _verify_approov_token(conn) do
    with [approov_token | _] <- Plug.Conn.get_req_header(conn, "approov-token"),
         {:ok, approov_token_claims} <- decode_and_verify(approov_token),
         true <- _has_expiration_claim(approov_token_claims)
      do
        IO.inspect(approov_token_claims, label: "CLAIMS")
        {:ok, conn, approov_token_claims}

      else

        [] ->
          Logger.debug("Missing the Approov token header!")
          {:error, conn}

        {:error, reason} when is_atom(reason) ->
          Logger.debug(Atom.to_string(reason))
          {:error, conn}

        {:error,  %ArgumentError{} = error} ->
          Logger.debug("Approov token may be an invalid JWT token, e.g: with an invalid number of segments!")
          IO.inspect error, label: "ERROR"
          {:error, conn}

        {:error, error} ->
          Logger.debug("Approov token verification failed with an unexpected reason for the error!")
          IO.inspect error, label: "ERROR"
          {:error, conn}

        false ->
          Logger.debug("Missing `exp` claim in a valid signed Approov token.")
          {:error, conn}
    end
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
