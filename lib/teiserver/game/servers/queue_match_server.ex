defmodule Teiserver.Game.QueueMatchServer do
  use GenServer
  require Logger
  alias Teiserver.Battle.Lobby
  alias Phoenix.PubSub
  alias Teiserver.{Coordinator, Client, Telemetry}

  @default_telemetry_interval 10_000
  @default_tick_interval 1_000

  @ready_wait_time 15

  # TODO - Convert this into a system where each match is a new process and the match can
  # tell the queue server to either re-add the players to the pool or remove them (as the match is going ahead)
  # currently as the queues get bigger they'll stall waiting for players to ready up but
  # it's good enough for now
  def handle_call(:get_state, _from, state) do
    {:reply, state, state}
  end

  def handle_call({:get, key}, _from, state) do
    {:reply, Map.get(state, key), state}
  end

  def handle_call({:add_player, userid}, _from, state) when is_integer(userid) do
    {resp, new_state} =
      case Enum.member?(state.unmatched_players ++ state.matched_players, userid) do
        true ->
          {:duplicate, state}

        false ->
          player_item = %{
            join_time: :erlang.system_time(:seconds),
            last_heartbeart: :erlang.system_time(:seconds),
          }

          new_state = %{
            state
            | unmatched_players: [userid | state.unmatched_players],
              player_count: state.player_count + 1,
              player_map: Map.put(state.player_map, userid, player_item)
          }

          PubSub.broadcast(
            Central.PubSub,
            "teiserver_queue:#{state.id}",
            {:queue_add_player, state.id, userid}
          )

          PubSub.broadcast(
            Central.PubSub,
            "teiserver_client_action_updates:#{userid}",
            {:client_action, :join_queue, userid, state.id}
          )

          {:ok, new_state}
      end

    {:reply, resp, new_state}
  end

  def handle_call({:remove_player, userid}, _from, state) when is_integer(userid) do
    {resp, new_state} =
      case Enum.member?(state.unmatched_players ++ state.matched_players, userid) do
        true ->
          new_state = remove_players(state, [userid])

          PubSub.broadcast(
            Central.PubSub,
            "teiserver_queue:#{state.id}",
            {:queue_remove_player, state.id, userid}
          )

          PubSub.broadcast(
            Central.PubSub,
            "teiserver_client_action_updates:#{userid}",
            {:client_action, :leave_queue, userid, state.id}
          )

          {:ok, new_state}

        false ->
          {:missing, state}
      end

    {:reply, resp, new_state}
  end

  def handle_call(:get_info, _from, state) do
    resp = %{
      last_wait_time: state.last_wait_time,
      player_count: state.player_count
    }

    {:reply, resp, state}
  end

  def handle_cast({:refresh_from_db, db_queue}, state) do
    update_state_from_db(state, db_queue)
  end

  def handle_cast({:player_accept, player_id}, state) when is_integer(player_id) do
    new_state =
      case player_id in state.matched_players do
        true ->
          new_waiting_for_players = List.delete(state.waiting_for_players, player_id)
          new_players_accepted = [player_id | state.players_accepted]

          interim_state = %{
            state
            | waiting_for_players: new_waiting_for_players,
              players_accepted: new_players_accepted
          }

          case Enum.empty?(new_waiting_for_players) do
            # That was the last one, go-time
            true ->
              try_setup_battle(interim_state)

            # Not ready quite yet, still waiting for at least one more
            false ->
              interim_state
          end

        # We're not waiting for this player to accept, ignore it for now
        false ->
          state
      end

    {:noreply, new_state}
  end

  def handle_cast({:player_decline, player_id}, state) when is_integer(player_id) do
    matched_with_removal = Enum.reject(state.matched_players, fn u -> u == player_id end)
    new_unmatched_players = matched_with_removal ++ state.unmatched_players
    new_player_map = Map.delete(state.player_map, player_id)

    new_state = %{state |
        finding_battle: false,
        unmatched_players: new_unmatched_players,
        matched_players: [],
        waiting_for_players: [],
        ready_started_at: nil,
        players_accepted: [],
        player_map: new_player_map
    }
    {:noreply, new_state}
  end

  def handle_info(:telemetry_tick, state) do
    Telemetry.cast_to_server({:matchmaking_update, state.id, %{
      last_wait_time: state.last_wait_time,
      player_count: state.player_count
    }})

    {:noreply, state}
  end

  def handle_info(:tick, state) do
    # Typically we need to check things like team size and the like
    # but for this test of concept stage we're going to just assume we need two players

    new_state =
      cond do
        # Trying to find a battle, not doing standard tick stuff
        state.finding_battle == true ->
          try_setup_battle(state)

        # This means we are not waiting for players, we can instead find some
        # TODO: Currently this is hard coded to waiting for 2 players so only allows 1v1
        state.ready_started_at == nil ->
          # First make sure we have enough players...
          if Enum.count(state.unmatched_players) >= state.team_size * state.team_count and state.waiting_for_players == [] and
               state.players_accepted == [] do
            # Now grab the players
            [p1, p2 | new_unmatched_players] = Enum.reverse(state.unmatched_players)

            # Count them as matched up
            new_matched_players = [p1, p2 | state.matched_players]

            # Send them ready up commands
            [p1, p2]
            |> Enum.each(fn userid ->
              PubSub.broadcast(
                Central.PubSub,
                "teiserver_client_messages:#{userid}",
                {:client_message, :matchmaking, userid, {:match_ready, state.id}}
              )
            end)

            # TODO: Remove the auto-ready part
            # new_matched_players
            # |> Enum.each(fn player_id ->
            #   GenServer.cast(self(), {:player_accept, player_id})
            # end)

            %{
              state
              | unmatched_players: new_unmatched_players,
                matched_players: new_matched_players,
                waiting_for_players: new_matched_players,
                ready_started_at: :erlang.system_time(:seconds),
                players_accepted: []
            }
          else
            state
          end

        # Waiting but haven't been waiting too long yet
        :erlang.system_time(:seconds) - state.ready_started_at <= state.ready_wait_time ->
          state

        # Need to cancel waiting, all players not yet matched decline
        :erlang.system_time(:seconds) - state.ready_started_at > state.ready_wait_time ->
          new_unmatched_players = state.players_accepted ++ state.unmatched_players
          new_player_map = Map.drop(state.player_map, state.waiting_for_players)

          %{state |
              finding_battle: false,
              unmatched_players: new_unmatched_players,
              matched_players: [],
              waiting_for_players: [],
              ready_started_at: nil,
              players_accepted: [],
              player_map: new_player_map
          }
      end

    new_state = %{new_state |
      player_count: Enum.count(state.unmatched_players) + Enum.count(state.matched_players),
    }

    PubSub.broadcast(
      Central.PubSub,
      "teiserver_queue_all_queues",
      {:queue_periodic_update, state.id, new_state.player_count, new_state.last_wait_time}
    )

    {:noreply, new_state}
  end

  def handle_info({:update, :settings, new_list}, state),
    do: {:noreply, %{state | settings: new_list}}

  def handle_info({:update, :map_list, new_list}, state),
    do: {:noreply, %{state | map_list: new_list}}

  # Used to remove players from all aspects of the queue, either because
  # they left or their game started
  @spec remove_players(Map.t(), [Integer.t()]) :: Map.t()
  defp remove_players(state, userids) do
    new_umatched = Enum.reject(state.unmatched_players, fn u -> u in userids end)
    new_matched = Enum.reject(state.matched_players, fn u -> u in userids end)
    new_player_map = Map.drop(state.player_map, userids)

    %{
      state
      | unmatched_players: new_umatched,
        matched_players: new_matched,
        player_map: new_player_map,
        player_count: Enum.count(new_player_map)
    }
  end

  # Try to setup a battle with the players currently readied up
  defp try_setup_battle(state) do
    # Send out the new battle stuff
    empty_battle = Lobby.find_empty_battle(fn l -> String.contains?(l.name, "EU ") end)

    case empty_battle do
      nil ->
        Logger.info("OldQueueServer try_setup_battle no empty battle")
        %{state | finding_battle: true}

      battle ->
        Logger.info("OldQueueServer try_setup_battle found empty battle")
        state.players_accepted
        |> Enum.each(fn userid ->
          Lobby.remove_user_from_any_battle(userid)

          PubSub.broadcast(
            Central.PubSub,
            "teiserver_client_messages:#{userid}",
            {:client_message, :matchmaking, userid, {:join_lobby, battle.id}}
          )
        end)

        midway_state = remove_players(state, state.players_accepted)

        # Coordinator sets up the battle
        Logger.info("OldQueueServer try_setup_battle starting battle setup")
        map_name = state.map_list |> Enum.random()
        Coordinator.send_to_host(empty_battle.id, "!preset duel")
        :timer.sleep(100)
        Coordinator.send_to_host(empty_battle.id, "!bset startpostype 2")
        :timer.sleep(100)
        Coordinator.send_to_host(empty_battle.id, "!autobalance off")
        :timer.sleep(100)
        Coordinator.send_to_host(empty_battle.id, "!map #{map_name}")
        :timer.sleep(100)

        # Now put the players on their teams, for now we're assuming every game is just a 1v1
        Logger.info("OldQueueServer try_setup_battle putting players on teams")
        [p1, p2 | _] = state.players_accepted
        Coordinator.cast_consul(battle.id, %{command: "change-battlestatus", remaining: p1, senderid: Coordinator.get_coordinator_userid(),
          status: %{
            team_number: 0,
            ally_team_number: 0,
            player: true,
            bonus: 0,
            ready: true
          }
        })
        Coordinator.cast_consul(battle.id, %{command: "change-battlestatus", remaining: p2, senderid: Coordinator.get_coordinator_userid(),
          status: %{
            team_number: 1,
            ally_team_number: 1,
            player: true,
            bonus: 0,
            ready: true
          }
        })

        # Update the lobby itself
        battle = Lobby.get_lobby(battle.id)
        new_tags = Map.put(battle.tags, "server/match/queue_id", state.id)
        Lobby.set_script_tags(battle.id, new_tags)

        # Give things time to propagate before we start
        :timer.sleep(1000)

        all_clients = Client.get_clients([p1, p2])

        all_players = all_clients
          |> Enum.map(fn c -> c.player end)
          |> Enum.all?

        all_synced = all_clients
          |> Enum.map(fn c -> c.sync == 1 end)
          |> Enum.all?

        cond do
          all_players == false ->
            Logger.info("OldQueueServer try_setup_battle cannot start as not all are players")
            Lobby.sayex(Coordinator.get_coordinator_userid, "Unable to start the lobby as one or more of the matched users are not a player. Please rejoin the queue and try again.", battle.id)

            battle = Lobby.get_lobby(battle.id)
            new_tags = Map.drop(battle.tags, ["server/match/queue_id"])
            Lobby.set_script_tags(battle.id, new_tags)

          all_synced == false ->
            Logger.info("OldQueueServer try_setup_battle cannot start as not all are synced")
            Lobby.sayex(Coordinator.get_coordinator_userid, "Unable to start the lobby as one or more of the matched players are unsynced. Please rejoin the queue and try again.", battle.id)

            battle = Lobby.get_lobby(battle.id)
            new_tags = Map.drop(battle.tags, ["server/match/queue_id"])
            Lobby.set_script_tags(battle.id, new_tags)

          true ->
            Logger.info("OldQueueServer try_setup_battle calling player cv start")
            Lobby.sayex(Coordinator.get_coordinator_userid, "Attempting to start the game, if this doesn't work feel free to start it yourselves and report to Teifion.", battle.id)
            :timer.sleep(100)
            Lobby.say(p1, "!cv forcestart", battle.id)
            :timer.sleep(100)
            Lobby.say(p2, "!y", battle.id)
            :timer.sleep(100)

            # Logger.info("OldQueueServer try_setup_battle calling forcestart")
            # Coordinator.send_to_host(empty_battle.id, "!forcestart")
            :timer.sleep(100)

            PubSub.broadcast(
              Central.PubSub,
              "teiserver_queue:#{state.id}",
              {:match_made, state.id, battle.id}
            )
        end

        %{
          midway_state
          | finding_battle: false,
            matched_players: [],
            waiting_for_players: [],
            ready_started_at: nil,
            players_accepted: []
        }
    end
  end

  @spec start_link(List.t()) :: :ignore | {:error, any} | {:ok, pid}
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts[:data], [])
  end

  defp update_state_from_db(state, db_queue) do
    Map.merge(state, %{
      id: db_queue.id,
      team_size: db_queue.team_size,
      map_list: db_queue.map_list |> Enum.map(fn m -> String.trim(m) end),
      settings: db_queue.settings,
    })
  end

  @spec init(Map.t()) :: {:ok, Map.t()}
  def init(opts) do
    tick_interval = Map.get(opts.queue.settings, "tick_interval", @default_tick_interval)
    :timer.send_interval(tick_interval, self(), :tick)
    :timer.send_interval(@default_telemetry_interval, self(), :telemetry_tick)

    # Update the queue pids cache to point to this process
    Horde.Registry.register(
      Teiserver.ServerRegistry,
      "OldQueueServer:#{opts.queue.id}",
      opts.queue.id
    )

    state = update_state_from_db(%{
       # Match ready stuff
       waiting_for_players: [],
       players_accepted: [],
       ready_started_at: nil,
       finding_battle: false,
       matchups: [],
       matched_players: [],
       unmatched_players: [],
       player_count: 0,
       team_count: 2,
       player_map: %{},
       last_wait_time: 0,
       ready_wait_time: opts.queue.settings["ready_wait_time"] || @ready_wait_time
     }, opts.queue)

    {:ok, state}
  end
end
