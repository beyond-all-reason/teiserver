defmodule Teiserver.Telemetry.TelemetryServer do
  use GenServer
  alias Teiserver.{Lobby, Client}
  alias Teiserver.Account.LoginThrottleServer
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
    matchmaking: %{},
    server: %{
      users_connected: 0,
      users_disconnected: 0,
      bots_connected: 0,
      bots_disconnected: 0,
      load: 0
    },
    total_clients_connected: 0,
    spring_server_messages_sent: 0,
    spring_server_batches_sent: 0,
    spring_client_messages_sent: 0,
    login_queue_length: 0
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
  def handle_cast(
        {:spring_messages_sent, _userid, server_count, _batch_count, client_count},
        state
      ) do
    {:noreply,
     %{
       state
       | spring_server_messages_sent: state.spring_server_messages_sent + server_count,
         spring_client_messages_sent: state.spring_client_messages_sent + client_count
     }}
  end

  def handle_cast({:matchmaking_update, queue_id, data}, %{matchmaking: matchmaking} = state) do
    new_matchmaking = Map.put(matchmaking, queue_id, data)
    {:noreply, %{state | matchmaking: new_matchmaking}}
  end

  @impl true
  def handle_call(:get_totals_and_reset, _from, state) do
    {:reply, get_totals(state), @default_state}
  end

  @spec report_telemetry(map()) :: :ok
  defp report_telemetry(state) do
    client =
      @client_states
      |> Map.new(fn cstate ->
        {cstate, state.client[cstate] |> Enum.count()}
      end)

    :telemetry.execute([:teiserver, :client], client, %{})
    :telemetry.execute([:teiserver, :battle], state.battle, %{})

    data = %{
      client: client,
      battle: state.battle,
      total_clients_connected: state.total_clients_connected
    }

    PubSub.broadcast(
      Teiserver.PubSub,
      "teiserver_telemetry",
      %{
        channel: "teiserver_telemetry",
        event: :data,
        data: data
      }
    )

    Teiserver.cache_put(:application_temp_cache, :telemetry_data, data)

    PubSub.broadcast(
      Teiserver.PubSub,
      "teiserver_public_stats",
      %{
        channel: "teiserver_public_stats",
        data: %{
          user_count: client.total,
          player_count: client.player,
          lobby_count: state.battle.total,
          in_progress_lobby_count: state.battle.in_progress,
          total_clients_connected: state.total_clients_connected
        }
      }
    )
  end

  @spec get_totals(map()) :: map()
  defp get_totals(state) do
    battles = Lobby.list_lobbies()
    client_ids = Client.list_client_ids()

    clients =
      client_ids
      |> Map.new(fn c -> {c, Client.get_client_by_id(c)} end)

    # Battle stats
    total_battles = Enum.count(battles)

    battles_in_progress =
      battles
      |> Enum.filter(fn battle ->
        # If the host is in-game, the battle is in progress!
        host = clients[battle.founder_id]
        host != nil and host.in_game
      end)

    # Client stats
    {player_ids, spectator_ids, lobby_ids, menu_ids} =
      clients
      |> Enum.reduce({[], [], [], []}, fn {userid, client}, {player, spectator, lobby, menu} ->
        add_to =
          cond do
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

    lobby_memberships =
      clients
      |> Map.values()
      |> Enum.reject(fn
        %{lobby_id: lobby_id} -> lobby_id == nil
        _ -> true
      end)
      |> Enum.reduce(%{}, fn client, memberships ->
        new_lobby_membership = [client.userid | Map.get(memberships, client.lobby_id, [])]
        Map.put(memberships, client.lobby_id, new_lobby_membership)
      end)

    login_queue_length = LoginThrottleServer.get_queue_length()

    counters = state.counters

    %{
      client: %{
        player: player_ids,
        spectator: spectator_ids,
        lobby: lobby_ids,
        menu: menu_ids,
        total: Enum.uniq(player_ids ++ spectator_ids ++ lobby_ids ++ menu_ids)
      },
      lobby_memberships: lobby_memberships,
      battle: %{
        total: total_battles,
        lobby: total_battles - Enum.count(battles_in_progress),
        in_progress: Enum.count(battles_in_progress),
        started: counters.matches_started,
        stopped: counters.matches_stopped
      },
      matchmaking: %{},
      server: %{
        users_connected: counters.users_connected,
        users_disconnected: counters.users_disconnected,
        bots_connected: counters.bots_connected,
        bots_disconnected: counters.bots_disconnected
      },
      total_clients_connected: Enum.count(clients),
      spring_server_messages_sent: state.spring_server_messages_sent,
      spring_server_batches_sent: state.spring_server_batches_sent,
      spring_client_messages_sent: state.spring_client_messages_sent,
      login_queue_length: login_queue_length,
      os_mon: get_os_mon_data()
    }
  end

  @spec get_os_mon_data :: map()
  def get_os_mon_data() do
    # cpu_per_core =
    #   case :cpu_sup.util([:detailed, :per_cpu]) do
    #     {:all, 0, 0, []} -> []
    #     cores -> Enum.map(cores, fn {n, busy, non_b, _} -> {n, Map.new(busy ++ non_b)} end)
    #   end

    # disk =
    #   case :disksup.get_disk_data() do
    #     [{'none', 0, 0}] -> []
    #     other -> other
    #   end

    process_counts = %{
      system_servers: Horde.Registry.count(Teiserver.ServerRegistry),
      throttle_servers: Horde.Registry.count(Teiserver.ThrottleRegistry),
      accolade_servers: Horde.Registry.count(Teiserver.AccoladesRegistry),
      consul_servers: Horde.Registry.count(Teiserver.ConsulRegistry),
      balancer_servers: Horde.Registry.count(Teiserver.BalancerRegistry),
      lobby_servers: Horde.Registry.count(Teiserver.LobbyRegistry),
      client_servers: Horde.Registry.count(Teiserver.ClientRegistry),
      party_servers: Horde.Registry.count(Teiserver.PartyRegistry),
      queue_wait_servers: Horde.Registry.count(Teiserver.QueueWaitRegistry),
      queue_match_servers: Horde.Registry.count(Teiserver.QueueMatchRegistry),
      managed_lobby_servers: Horde.Registry.count(Teiserver.LobbyPolicyRegistry)
    }

    process_counts =
      Map.merge(process_counts, %{
        beam_total: Process.list() |> Enum.count(),
        teiserver_total: process_counts |> Map.values() |> Enum.sum()
      })

    %{
      cpu_avg1: :cpu_sup.avg1(),
      cpu_avg5: :cpu_sup.avg5(),
      cpu_avg15: :cpu_sup.avg15(),
      cpu_nprocs: :cpu_sup.nprocs(),
      # cpu_per_core: cpu_per_core |> Map.new(),
      # disk: disk |> Map.new(),
      system_mem: :memsup.get_system_memory_data() |> Map.new(),
      processes: process_counts
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
