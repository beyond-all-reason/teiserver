defmodule Teiserver.Telemetry.TelemetryServer do
  use GenServer

  @tick_period 5_000

  # Telemetry todo lists
  # TODO: Beherith: clients logged in, clients ingame, clients singpleplayer, clients afk, clients that are bots are not clients

  def set(table, key, value) do
    GenServer.cast(__MODULE__, {:set, table, key, value})
  end

  def increase(table, key) do
    GenServer.cast(__MODULE__, {:increase, table, key})
  end

  def decrease(table, key) do
    GenServer.cast(__MODULE__, {:decrease, table, key})
  end

  def get_state() do
    GenServer.call(__MODULE__, :get_state)
  end

  @impl true
  def handle_info(:tick, state) do
    state = get_totals(state)
    report_telemetry(state)

    {:noreply, state}
  end

  @impl true
  def handle_cast({:increase, table, key}, state) do
    new_table = Map.get(state, table)
    |> Map.update!(key, &(&1 + 1))

    {:noreply, Map.put(state, table, new_table)}
  end

  def handle_cast({:decrease, table, key}, state) do
    new_table = Map.get(state, table)
    |> Map.update!(key, &(&1 - 1))

    {:noreply, Map.put(state, table, new_table)}
  end

  @impl true
  def handle_call(:get_state, _from, state) do
    {:reply, state, state}
  end

  @spec report_telemetry(Map.t()) :: :ok
  defp report_telemetry(state) do
    :telemetry.execute([:teiserver, :client], state.client, %{})
    :telemetry.execute([:teiserver, :battle], state.battle, %{})
  end

  @spec get_totals(Map.t()) :: Map.t()
  defp get_totals(state) do
    %{state |
      client: do_total(state.client),
      battle: do_total(state.battle)
    }
  end

  defp do_total(table) do
    new_total = table
    |> Enum.map(fn {k, v} ->
      if k == :total, do: 0, else: v
    end)
    |> Enum.sum

    %{table | total: new_total}
  end

  # Startup
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts[:data], opts)
  end

  @impl true
  def init(_opts) do
    :timer.send_interval(@tick_period, self(), :tick)

    {:ok, %{
      client: %{
        total: 0,
        menu: 0,
        battle: 0
      },
      battle: %{
        total: 0,
        lobby: 0,
        in_progress: 0
      }
    }}
  end
end
