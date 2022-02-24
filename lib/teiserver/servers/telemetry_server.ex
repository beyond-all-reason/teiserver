defmodule Teiserver.Telemetry.TelemetryServer do
  use GenServer
  alias Teiserver.Battle.Lobby
  alias Teiserver.Client
  require Logger
  alias Phoenix.PubSub

  @client_states ~w(lobby menu player spectator total)a
  @tick_period 9_000
  @counters ~w(matches_started matches_stopped users_connected users_disconnected bots_connected bots_disconnected)a
  @default_state %{
    counters: Map.new(@counters, fn c -> {c, 0} end),
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
    },
    matchmaking: %{

    },
    server: %{
      users_connected: 0,
      users_disconnected: 0,

      bots_connected: 0,
      bots_disconnected: 0,

      load: 0,
    }
  }

  @impl true
  def handle_info(:tick, state) do
    totals = get_totals(state)
    report_telemetry(totals)

    {:noreply, state}
  end

  def handle_info({:increment, counter}, state) do
    current = Map.get(state.counters, counter, 0)
    new_counters = Map.put(state.counters, counter, current + 1)
    {:noreply, %{state | counters: new_counters}}
  end

  @impl true
  def handle_call(:get_state, _from, state) do
    {:reply, state, state}
  end

  def handle_call(:get_totals_and_reset, _from, state) do
    {:reply, get_totals(state), @default_state}
  end

  @spec report_telemetry(Map.t()) :: :ok
  defp report_telemetry(state) do
    client = @client_states
    |> Map.new(fn cstate ->
      {cstate, state.client[cstate] |> Enum.count}
    end)

    :telemetry.execute([:teiserver, :client], client, %{})
    :telemetry.execute([:teiserver, :battle], state.battle, %{})

    # TODO: Is there a way to hook into the above data for our liveviews?
    PubSub.broadcast(
      Central.PubSub,
      "teiserver_telemetry",
      {:teiserver_telemetry, %{
        client: client,
        battle: state.battle
      }}
    )
  end

  @spec get_totals(Map.t()) :: Map.t()
  defp get_totals(state) do
    battles = Lobby.list_lobbies()
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
          client.lobby_id == nil -> :menu

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

    counters = state.counters

    # TODO: Change this to use :os_mon like the liveview dashboard
    {load_str, _} = System.cmd("uptime", [])
    [_, l1, _, _] = Regex.run(~r/load average: ([\d\.]+), ([\d\.]+), ([\d\.]+)/, load_str)
    {load, _} = Float.parse(l1)

    %{
      client: %{
        player: player_ids,
        spectator: spectator_ids,
        lobby: lobby_ids,
        menu: menu_ids,
        total: Enum.uniq(player_ids ++ spectator_ids ++ lobby_ids ++ menu_ids)
      },
      battle: %{
        total: total_battles,
        lobby: total_battles - Enum.count(battles_in_progress),
        in_progress: Enum.count(battles_in_progress),
        started: counters.matches_started,
        stopped: counters.matches_stopped,
      },
      matchmaking: %{

      },
      server: %{
        users_connected: counters.users_connected,
        users_disconnected: counters.users_disconnected,

        bots_connected: counters.bots_connected,
        bots_disconnected: counters.bots_disconnected,

        load: load,
      }
    }
  end

  defp reset_state(state) do
    Map.merge(@default_state, Map.take(state, [:counters]))
  end

  # Startup
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts[:data], opts)
  end

  @impl true
  def init(_opts) do
    :timer.send_interval(@tick_period, self(), :tick)

    {:ok, reset_state(%{})}
  end
end
