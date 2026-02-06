defmodule ApproovApplication.MixProject do
  use Mix.Project

  def project do
    [
      app: :approov_application,
      version: "0.1.0",
      elixir: "~> 1.19",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application do
    [
      mod: {ApproovApplication.Application, []},
      extra_applications: [:logger, :runtime_tools]
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp deps do
    [
      {:phoenix, "~> 1.8"},
      {:phoenix_pubsub, "~> 2.2.0"},
      {:plug_cowboy, "~> 2.7.5"},
      {:jason, "~> 1.4"},
      {:guardian, "~> 2.4"}
    ]
  end
end
