defmodule Teiserver.OpenTelemetrySystem do
  use DynamicSupervisor
  use Task

  def start_link(_) do
    DynamicSupervisor.start_link(__MODULE__, [], name: __MODULE__)
  end

  @impl true
  def init(_) do
    {:ok, sup_flags} = DynamicSupervisor.init(strategy: :one_for_one)

    if use_opentelemetry?() do
      Task.async(fn ->
        DynamicSupervisor.start_child(
          __MODULE__,
          Supervisor.child_spec(Teiserver.Bridge.OpenTelemetrySupervisor, restart: :temporary)
        )
      end)
    end

    {:ok, sup_flags}
  end

  @spec use_opentelemetry?() :: boolean
  def use_opentelemetry?() do
    Application.get_env(:teiserver, Teiserver)[:enable_opentelemetry]
  end
end
