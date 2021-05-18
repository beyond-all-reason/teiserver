defmodule Teiserver.Telemetry.TelemetryServer do
  use GenServer
  alias Teiserver.Battle
  alias Teiserver.Client

  @tick_period 9_000
  @default_state %{
      client: %{
        total: 0,
        menu: 0,
        battle: 0,
        # spectator: 0,
        player: 0
      },
      battle: %{
        total: 0,
        lobby: 0,
        in_progress: 0
      }
    }

  @impl true
  def handle_info(:tick, state) do
    state = get_totals(state)
    report_telemetry(state)

    {:noreply, state}
  end

  # @impl true
  # def handle_cast({:increase, table, key}, state) do
  #   new_table = Map.get(state, table)
  #   |> Map.update!(key, &(&1 + 1))

  #   {:noreply, Map.put(state, table, new_table)}
  # end

  # def handle_cast({:decrease, table, key}, state) do
  #   new_table = Map.get(state, table)
  #   |> Map.update!(key, &(&1 - 1))

  #   {:noreply, Map.put(state, table, new_table)}
  # end

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
  defp get_totals(_state) do
    battles = Battle.list_battles()
    client_ids = Client.list_client_ids()

    # {players, spectators} = battles
    #   |> Enum.reduce({0, 0}, fn (battle, {pcount, scount}) ->
    #     {
    #       pcount + Enum.count(battle.players),
    #       scount + Enum.count(battle.spectators)
    #     }
    #   end)
    players = battles
      |> Enum.reduce(0, fn (battle, count) ->
        count + Enum.count(battle.players)
      end)

    total_clients = Enum.count(client_ids)
    total_battles = Enum.count(battles)

    %{
      client: %{
        total: total_clients,
        menu: total_clients - players - total_battles,
        battle: players + total_battles,
        # spectator: spectators,
        # player: players
      },
      battle: %{
        total: total_battles,
        lobby: total_battles,
        in_progress: 0
      }
    }
  end

  # defp do_total(table) do
  #   new_total = table
  #   |> Enum.map(fn {k, v} ->
  #     if k == :total, do: 0, else: v
  #   end)
  #   |> Enum.sum

  #   %{table | total: new_total}
  # end

  # Startup
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts[:data], opts)
  end

  @impl true
  def init(_opts) do
    :timer.send_interval(@tick_period, self(), :tick)

    {:ok, @default_state}
  end
end
