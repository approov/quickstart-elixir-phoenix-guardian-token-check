defmodule ApproovApplication.ApproovTokenVerifier do
  use Guardian, otp_app: :approov_application
  require Logger

  @approov_token_header "approov-token"
  @secret_placeholder "approov_base64url_secret_here"
  @secret_log_key {__MODULE__, :secret_issue_checked}

  @type verify_error ::
          :missing_approov_token
          | :missing_exp_claim
          | :invalid_exp_claim
          | :approov_token_expired
          | :missing_pay_claim
          | :invalid_pay_claim
          | :token_binding_mismatch
          | {:missing_binding_header, String.t()}
          | any()

  @impl true
  def subject_for_token(_resource, _claims), do: {:ok, "approov"}

  @impl true
  def resource_from_claims(_claims), do: {:ok, :approov}

  @spec verify_request(Plug.Conn.t(), [String.t()] | nil) ::
          {:ok, map()} | {:error, verify_error()}
  def verify_request(conn, binding_headers) do
    log_secret_issue_once()

    with {:ok, token} <- fetch_approov_token(conn),
         {:ok, claims} <- decode_and_verify(token),
         :ok <- verify_expiration(claims),
         :ok <- verify_binding(conn, claims, binding_headers) do
      {:ok, claims}
    else
      {:error, reason} ->
        Logger.debug("Approov verification failed: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @spec fetch_approov_token(Plug.Conn.t()) :: {:ok, String.t()} | {:error, :missing_approov_token}
  defp fetch_approov_token(conn) do
    case Plug.Conn.get_req_header(conn, @approov_token_header) do
      [token | _] -> {:ok, token}
      _ -> {:error, :missing_approov_token}
    end
  end

  @spec verify_expiration(map()) ::
          :ok | {:error, :missing_exp_claim | :invalid_exp_claim | :approov_token_expired}
  defp verify_expiration(%{"exp" => exp}) do
    exp_unix =
      cond do
        is_integer(exp) ->
          exp

        is_float(exp) ->
          trunc(exp)

        is_binary(exp) ->
          case Integer.parse(String.trim(exp)) do
            {value, ""} -> value
            :error -> nil
            {_value, _rest} -> nil
          end

        true ->
          nil
      end

    case exp_unix do
      nil ->
        {:error, :invalid_exp_claim}

      timestamp when is_integer(timestamp) ->
        now = System.system_time(:second)

        if timestamp > now do
          :ok
        else
          {:error, :approov_token_expired}
        end
    end
  end

  defp verify_expiration(_claims), do: {:error, :missing_exp_claim}

  @spec verify_binding(Plug.Conn.t(), map(), [String.t()] | nil) ::
          :ok | {:error, verify_error()}
  defp verify_binding(_conn, _claims, binding_headers) when binding_headers in [nil, []] do
    :ok
  end

  defp verify_binding(conn, %{"pay" => pay_claim}, binding_headers) when is_binary(pay_claim) do
    with {:ok, binding_input} <- binding_input(conn, binding_headers),
         expected_hash <- binding_hash(binding_input),
         :ok <- compare_pay_claim(pay_claim, expected_hash) do
      :ok
    else
      {:error, reason} -> {:error, reason}
    end
  end

  defp verify_binding(_conn, %{"pay" => _invalid_pay_claim}, _binding_headers),
    do: {:error, :invalid_pay_claim}

  defp verify_binding(_conn, _claims, _binding_headers), do: {:error, :missing_pay_claim}

  # The binding input is a string built by concatenating values in the exact
  # order configured for the route.
  @spec binding_input(Plug.Conn.t(), [String.t()]) ::
          {:ok, String.t()} | {:error, {:missing_binding_header, String.t()}}
  defp binding_input(conn, headers) do
    headers
    |> Enum.map(&String.downcase/1)
    |> Enum.reduce_while([], fn header, acc ->
      case Plug.Conn.get_req_header(conn, header) do
        [value | _] -> {:cont, [value | acc]}
        _ -> {:halt, {:error, {:missing_binding_header, header}}}
      end
    end)
    |> case do
      {:error, _} = error -> error
      values -> {:ok, values |> Enum.reverse() |> Enum.join("")}
    end
  end

  @spec binding_hash(String.t()) :: String.t()
  defp binding_hash(value) do
    :crypto.hash(:sha256, value)
    |> Base.encode64()
  end

  @spec compare_pay_claim(String.t(), String.t()) :: :ok | {:error, :token_binding_mismatch}
  defp compare_pay_claim(pay_claim, expected_hash) do
    pay_claim = String.trim(pay_claim)

    if byte_size(pay_claim) == byte_size(expected_hash) and
         Plug.Crypto.secure_compare(pay_claim, expected_hash) do
      :ok
    else
      {:error, :token_binding_mismatch}
    end
  end

  defp log_secret_issue_once do
    case :persistent_term.get(@secret_log_key, :unchecked) do
      :unchecked ->
        case secret_issue() do
          nil ->
            :persistent_term.put(@secret_log_key, :ok)

          message ->
            Logger.error(message)
            :persistent_term.put(@secret_log_key, :invalid)
        end

      _ ->
        :ok
    end
  end

  @spec secret_issue() :: nil | String.t()
  defp secret_issue do
    value = System.get_env("APPROOV_BASE64URL_SECRET")

    cond do
      value in [nil, ""] ->
        "Required secret is not set"

      value == @secret_placeholder ->
        "Required secret is not set"

      valid_base64url?(value) ->
        nil

      valid_base64?(value) ->
        nil

      true ->
        "Required secret is invalid"
    end
  end

  @spec valid_base64url?(String.t()) :: boolean()
  defp valid_base64url?(value) do
    case Base.url_decode64(value, padding: false) do
      {:ok, _} -> true
      :error -> false
    end
  end

  @spec valid_base64?(String.t()) :: boolean()
  defp valid_base64?(value) do
    case Base.decode64(value) do
      {:ok, _} -> true
      :error -> false
    end
  end
end
