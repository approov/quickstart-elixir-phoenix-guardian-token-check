# Approov Token Binding Integration Example

This Approov integration example is from where the code example for the [Approov token binding check quickstart](/docs/APPROOV_TOKEN_BINDING_QUICKSTART.md) is extracted, and you can use it as a playground to better understand how simple and easy it is to implement [Approov](https://approov.io) in an Elixir Phoenix API server.

## TOC - Table of Contents

* [Why?](#why)
* [How it Works?](#how-it-works)
* [Requirements](#requirements)
* [Try the Approov Integration Example](#try-the-approov-integration-example)


## Why?

To lock down your API server to your mobile app. Please read the brief summary in the [README](/README.md#why) at the root of this repo or visit our [website](https://approov.io/product.html) for more details.

[TOC](#toc---table-of-contents)


## How it works?

The Elixir Phoenix API server is very simple and is defined in the project located at [src/approov-protected-server/token-binding-check/hello](/src/approov-protected-server/token-binding-check/hello). Take a look at the [Approov Plug](/src/approov-protected-server/token-binding-check/hello/lib/hello_web/plugs/approov_token_plug.ex) module, and search for the `_verify_approov_token/1` and `_verify_approov_token_binding/2` functions to see the simple code for the checks.

For more background on Approov, see the overview in the [README](/README.md#how-it-works) at the root of this repo.

[TOC](#toc---table-of-contents)


## Requirements

To run this example you will need to have Elixir and Phoenix installed. If you don't have then please follow the official installation instructions from [here](https://hexdocs.pm/phoenix/installation.html#content) to download and install them.

[TOC](#toc---table-of-contents)


## Try the Approov Integration Example

First, you need to set the dummy secret as explained [here](/README.md#the-dummy-secret).

Next, you need to install the dependencies. From the `src/approov-protected-server/token-binding-check/hello` folder execute:

```text
mix deps.get
```

Now, you can run this example from the `src/approov-protected-server/token-binding-check/hello` folder with:

```text
iex -S mix phx.server
```

Finally, you can test that the Approov integration example works as expected with this [Postman collection](/README.md#testing-with-postman) or with some cURL requests [examples](/README.md#testing-with-curl).

[TOC](#toc---table-of-contents)
