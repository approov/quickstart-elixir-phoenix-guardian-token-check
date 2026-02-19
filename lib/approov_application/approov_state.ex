defmodule ApproovApplication.ApproovState do
  use Agent

  @name __MODULE__

  @spec start_link(any()) :: {:error, any()} | {:ok, pid()}
  def start_link(_opts) do
    Agent.start_link(fn -> %{enabled: true} end, name: @name)
  end

  @spec enabled?() :: boolean()
  def enabled? do
    Agent.get(@name, & &1.enabled)
  end

  @spec enable() :: :ok
  def enable do
    Agent.update(@name, &Map.put(&1, :enabled, true))
  end

  @spec disable() :: :ok
  def disable do
    Agent.update(@name, &Map.put(&1, :enabled, false))
  end
end
