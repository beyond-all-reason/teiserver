defmodule Teiserver.TelemetryServer do
  use GenServer
  alias Teiserver.Client
  alias Teiserver.Battle

  @tick_period 5_000
  @db_cycles 60_000 / @tick_period

  @impl true
  def handle_info(:tick, state) do
    state = get_telemetry(state)
    report_telemtry(state)

    new_cycle = if state.cycle == 0 do
      db_store_telemetry(state)
      @db_cycles
    else
      state.cycle - 1
    end

    {:noreply, %{state | cycle: new_cycle}}
  end

  @spec db_store_telemetry(Map.t()) :: :ok
  defp db_store_telemetry(_state) do
    # Store telemtry in the database here
    :ok
  end

  @spec get_telemetry(Map.t()) :: Map.t()
  defp get_telemetry(state) do
    %{state |
      clients: Client.list_client_ids() |> Enum.count,
      battles: Battle.list_battle_ids() |> Enum.count,
    }
  end

  @spec report_telemtry(Map.t()) :: :ok
  defp report_telemtry(state) do
    :telemetry.execute([:teiserver, :client], %{count: state.clients}, %{})
    :telemetry.execute([:teiserver, :battle], %{count: state.battles}, %{})
  end

  # Startup
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts[:data], opts)
  end

  @impl true
  def init(_opts) do
    :timer.send_interval(@tick_period, self(), :tick)

    {:ok, %{
      clients: 0,
      battles: 0,
      cycle: @db_cycles
    }}
  end
end
