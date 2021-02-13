defmodule Teiserver.Benchmark.StatsClient do
  @moduledoc """
  A client that tracks various statistics
  """

  require Logger
  @tick_interval 3_000

  use GenServer

  # GenServer callbacks
  def handle_info({:ping, p}, state) do
    new_state = %{state | pings: state.pings ++ [p]}
    {:noreply, new_state}
  end

  def handle_info(:tick, state) do
    Logger.warn("Adding users")
    1..25
    |> Enum.each(fn i ->
      id = "user_#{state.tick}_#{i}"
      {:ok, _pid} = DynamicSupervisor.start_child(Teiserver.Benchmark.UserSupervisor, {
        Teiserver.Benchmark.UserClient,
        name: via_user_tuple(id),
        data: %{
          id: id,
          tick: state.tick,
          stats: self()
        },
      })
    end)

    Logger.warn("Adding silents")
    1..25
    |> Enum.each(fn i ->
      id = "silent_#{state.tick}_#{i}"
      {:ok, _pid} = DynamicSupervisor.start_child(Teiserver.Benchmark.SilentSupervisor, {
        Teiserver.Benchmark.SilentClient,
        name: via_silent_tuple(id),
        data: %{
          id: id,
          tick: state.tick
        },
      })
    end)

    Logger.warn("Averaging")
    # Print stats
    Logger.warn("Printing")
    average_ping = Enum.sum(state.pings)/max(Enum.count(state.pings),1)
    IO.puts "Tick: #{state.tick}
Users: #{Registry.count(Teiserver.Benchmark.UserRegistry)}
Silents: #{Registry.count(Teiserver.Benchmark.SilentRegistry)}
Avg ping: #{round(average_ping*100)/100}ms, Pings: #{Enum.count(state.pings)}
"

    new_state = %{state | tick: state.tick + 1, pings: []}
    {:noreply, new_state}
  end

  # def handle_cast({:add, module, section, permissions}, {table, permission_state}) do
  #   permission_state = Map.put(permission_state, {module, section}, permissions)
  #   :ets.insert(table, {{module, section}, permissions})
  #   {:noreply, {table, permission_state}}
  # end

  # Startup
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, [], opts)
  end

  def init(_opts) do
    Logger.warn("Starting stats")

    :timer.send_interval(@tick_interval, self(), :tick)
    {:ok, %{
      tick: 1,
      users: 0,
      silents: 0,
      pings: []
    }}
  end

  defp via_user_tuple(id) do
    {:via, Registry, {Teiserver.Benchmark.UserRegistry, id}}
  end

  defp via_silent_tuple(id) do
    {:via, Registry, {Teiserver.Benchmark.SilentRegistry, id}}
  end
end
