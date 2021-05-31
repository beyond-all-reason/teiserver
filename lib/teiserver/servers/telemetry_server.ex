defmodule Teiserver.Telemetry.TelemetryServer do
  use GenServer
  alias Teiserver.Battle
  alias Teiserver.Client

  @tick_period 9_000
  @default_state %{
      client: %{
        player: [],
        spectator: [],
        lobby: [],
        menu: []
      },
      battle: %{
        total: 0,
        lobby: 0,
        in_progress: 0,

        # Battles completed as part of this tick, not a cumulative total
        # reset when the reset command is sent
        completed: 0
      }
    }

  @impl true
  def handle_info(:tick, state) do
    state = get_totals(state)
    report_telemetry(state)

    {:noreply, state}
  end

  @impl true
  def handle_call(:get_state, _from, state) do
    {:reply, state, state}
  end

  def handle_call(:get_state_and_reset, _from, state) do
    {:reply, state, @default_state}
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
    clients = client_ids
      |> Map.new(fn c -> {c, Client.get_client_by_id(c)} end)

    # Battle stats
    total_battles = Enum.count(battles)
    battles_in_progress = battles
    |> Enum.filter(fn battle ->
        # If the host is in-game, the battle is in progress!
        host = clients[battle.founder_id]
        host != nil and host.in_game
      end)

    # Client stats
    {player_ids, spectator_ids, lobby_ids, menu_ids} = clients
      |> Enum.reduce({[], [], [], []}, fn ({userid, client}, {player, spectator, lobby, menu}) ->
        add_to = cond do
          client == nil -> nil
          client.bot == true -> nil
          client.battle_id == nil -> :menu

          # Client is involved in a battle in some way
          # In this case they are not in a game, they are in a battle lobby
          client.in_game == false -> :lobby

          # User is in a game, are they a player or a spectator?
          client.player == false -> :spectator
          client.player == true -> :player
        end

        case add_to do
          nil -> {player, spectator, lobby, menu}
          :player -> {[userid | player], spectator, lobby, menu}
          :spectator -> {player, [userid | spectator], lobby, menu}
          :lobby -> {player, spectator, [userid | lobby], menu}
          :menu -> {player, spectator, lobby, [userid | menu]}
        end
      end)

    %{
      client: %{
        player: player_ids,
        spectator: spectator_ids,
        lobby: lobby_ids,
        menu: menu_ids,
        total: client_ids
      },
      battle: %{
        total: total_battles,
        lobby: total_battles - Enum.count(battles_in_progress),
        in_progress: Enum.count(battles_in_progress)
      }
    }
  end

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
