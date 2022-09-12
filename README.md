# Approov QuickStart - Elixir Phoenix Guardian Token Check

[Approov](https://approov.io) is an API security solution used to verify that requests received by your backend services originate from trusted versions of your mobile apps.

This repo implements the Approov server-side request verification code in [Elixir](https://elixir-lang.org/), which performs the verification check before allowing valid traffic to be processed by the API endpoint.

This is an Approov integration quickstart example for the Elixir Phoenix framework, that uses the Guardian library to check the Approov token. If you are looking for another Elixir integration you can check our list of [quickstarts](https://approov.io/docs/latest/approov-integration-examples/backend-api/), and if you don't find what you are looking for, then please let us know [here](https://approov.io/contact).



## Approov Integration Quickstart

The quickstart was tested with the following Operating Systems:

* Ubuntu 20.04
* MacOS Big Sur
* Windows 10 WSL2 - Ubuntu 20.04

First, setup the [Approov CLI](https://approov.io/docs/latest/approov-installation/index.html#initializing-the-approov-cli).

Now, register the API domain for which Approov will issues tokens:

```bash
approov api -add api.example.com
```

Next, enable your Approov `admin` role with:

```bash
eval `approov role admin`
````

For the Windows powershell:

```bash
set APPROOV_ROLE=admin:___YOUR_APPROOV_ACCOUNT_NAME_HERE___
````

Now, retrieve the [Approov secret](https://approov.io/docs/latest/approov-usage-documentation/#account-secret-key-export):

```bash
approov secret -get base64Url
```

Next, export the Approov secret into the environment:

```bash
export APPROOV_BASE64URL_SECRET=approov_base64url_secret_here
```

Now, you need to retrieve the Approov secret from your running application. From Elixir `1.11` we have the runtime configuration, that will run every-time a release or a Mix project is started, thus the ideal place to retrieve the Aproov secret from the environment. Add the following code to your `config/runtime.exs`:

```elixir
approov_secret =
  System.get_env("APPROOV_BASE64_SECRET") ||
    raise "Environment variable APPROOV_BASE64_SECRET is missing."

config :YOUR_APP, YOUR_APP.ApproovTokenPlug,
  allowed_algos: ["HS256"],
  secret_key: Base.decode64!(approov_secret)
```

> **NOTE:** If you are below Elixir `1.11` then follow [this quickstart](/docs/APPROOV_TOKEN_QUICKSTART.md#approov-secret) steps to add the Approov secret to your application.

Next, to check the Approov token you need to add the [ueberauth/guardian](https://github.com/ueberauth/guardian) package to your dependencies on `mix.exs`:

```elixir
{:guardian, "~> 2.0"}
```

Now, you can install it with:

```
mix install
```

Next, add the [Approov Token Plug](/src/approov-protected-server/token-check/hello/lib/hello_web/plugs/approov_token_plug.ex) module to your project at `lib/your_app_web/plugs/approov_token_plug.ex`:

```elixir
defmodule YOUR_APP.ApproovTokenPlug do
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
    with {:ok, conn, _approov_token_claims} <- _verify_approov_token(conn) do
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
        # You may want to add some logging here
        {:error, conn}

      {:error, reason} when is_atom(reason) ->
        # You may want to add some logging here
        {:error, conn}

      {:error, %ArgumentError{} = error} ->
        # You may want to add some logging here
        {:error, conn}

      {:error, error} ->
        # You may want to add some logging here
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
    {timestamp, _decimals} = Integer.parse("#{timestamp}")
    DateTime.from_unix!(timestamp)
  end

  defp _halt_connection(conn) do
    conn
    |> Plug.Conn.put_status(401)
    |> Phoenix.Controller.json(%{})
    |> Plug.Conn.halt()
  end
end
```

> **NOTE:** When the Approov token validation fails we return a `401` with an empty body, because we don't want to give clues to an attacker about the reason the request failed, and you can go even further by returning a `400`.

Now, add the [Approov Token Plug](/src/approov-protected-server/token-check/hello/lib/hello_web/plugs/approov_token_plug.ex) to the `:api` pipeline on your Phoenix router `lib/your_app_web/router.ex`:

```elixir
pipeline :api do
  plug :accepts, ["json"]

  # Ideally you will not want to add any other Plug before the Approov Token
  # check to protect your server from wasting resources in processing requests
  # not having a valid Approov token. This increases availability for your
  # users during peak time or in the event of a DoS attack(We all know the
  # BEAM design allows to cope very well with this scenarios, but best to play
  # in the safe side).
  plug YourAppWeb.ApproovTokenPlug
end
```

Not enough details in the bare bones quickstart? No worries, check the [detailed quickstarts](QUICKSTARTS.md) that contain a more comprehensive set of instructions, including how to test the Approov integration.


## More Information

* [Approov Overview](OVERVIEW.md)
* [Detailed Quickstarts](QUICKSTARTS.md)
* [Step by Step Examples](EXAMPLES.md)
* [Testing](TESTING.md)

### System Clock

In order to correctly check for the expiration times of the Approov tokens is very important that the backend server is synchronizing automatically the system clock over the network with an authoritative time source. In Linux this is usually done with a NTP server.


## Issues

If you find any issue while following our instructions then just report it [here](https://github.com/approov/quickstart-elixir-phoenix-guardian-token-check/issues), with the steps to reproduce it, and we will sort it out and/or guide you to the correct path.


## Useful Links

If you wish to explore the Approov solution in more depth, then why not try one of the following links as a jumping off point:

* [Approov Free Trial](https://approov.io/signup)(no credit card needed)
* [Approov Get Started](https://approov.io/product/demo)
* [Approov QuickStarts](https://approov.io/docs/latest/approov-integration-examples/)
* [Approov Docs](https://approov.io/docs)
* [Approov Blog](https://approov.io/blog/)
* [Approov Resources](https://approov.io/resource/)
* [Approov Customer Stories](https://approov.io/customer)
* [Approov Support](https://approov.io/contact)
* [About Us](https://approov.io/company)
* [Contact Us](https://approov.io/contact)
