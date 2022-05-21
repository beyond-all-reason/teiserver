defmodule Teiserver.Game.QueueMatchServer do
  use GenServer
  require Logger
  alias Teiserver.Battle.Lobby
  alias Teiserver.Data.Matchmaking
  alias Phoenix.PubSub
  alias Teiserver.{Coordinator, Client, Telemetry}

  @tick_interval 500
  @ready_wait_time 15_000

  def handle_cast({:player_accept, player_id}, state) when is_integer(player_id) do
    new_state =
      case player_id in state.pending_accepts do
        true ->
          new_pending_accepts = List.delete(state.pending_accepts, player_id)

          interim_state = %{
            state |
              pending_accepts: new_pending_accepts,
              accepted_users: [player_id | state.accepted_users]
          }

          case Enum.empty?(new_pending_accepts) do
            # That was the last one, go-time
            true ->
              try_setup_lobby(interim_state)

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
    new_state = %{
      state |
        pending_accepts: List.delete(state.pending_accepts, player_id),
        declined_users: [player_id | state.declined_users]
    }

    {:noreply, new_state}
  end

  @impl true
  def handle_info(:end_waiting, state) do
    cancel_match(state)
  end

  def handle_info(:tick, %{pending_accepts: [], declined_users: []} = state) do
    # Typically we need to check things like team size and the like
    # but for this test of concept stage we're going to just assume we need two players

    new_state =
      cond do
        # Trying to find a battle, not doing standard tick stuff
        state.finding_battle == true ->
          try_setup_lobby(state)

        # This means we are not waiting for players, we can instead find some
        # TODO: Currently this is hard coded to waiting for 2 players so only allows 1v1
        state.ready_started_at == nil ->
          # First make sure we have enough players...
          if Enum.count(state.unmatched_players) >= state.team_size * state.team_count and state.pending_accepts == [] and
               state.accepted_users == [] do
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
                pending_accepts: new_matched_players,
                ready_started_at: System.system_time(:second),
                accepted_users: []
            }
          else
            state
          end

        # Waiting but haven't been waiting too long yet
        System.system_time(:second) - state.ready_started_at <= state.ready_wait_time ->
          state

        # Need to cancel waiting, all players not yet matched decline
        System.system_time(:second) - state.ready_started_at > state.ready_wait_time ->
          new_unmatched_players = state.accepted_users ++ state.unmatched_players
          new_player_map = Map.drop(state.player_map, state.pending_accepts)

          %{state |
              finding_battle: false,
              unmatched_players: new_unmatched_players,
              matched_players: [],
              pending_accepts: [],
              ready_started_at: nil,
              accepted_users: [],
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

  # No more to accept but declines is non-zero
  def handle_info(:tick, %{pending_accepts: []} = state) do
    cancel_match(state)
  end

  # We have pending accepts, the tick does nothing
  def handle_info(:tick, state), do: {:noreply, state}

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

  defp send_invites(%{users: users} = state) do
    users
      |> Enum.map(fn userid ->
        PubSub.broadcast(
          Central.PubSub,
          "teiserver_client_messages:#{userid}",
          {:client_message, :matchmaking, userid, {:match_ready, {state.queue_id, state.match_id}}}
        )
      end)
  end

  defp cancel_match(state) do
    # These users go back into the queue
    state.accepted_users
      |> Enum.each(fn userid ->
        PubSub.broadcast(
          Central.PubSub,
          "teiserver_client_messages:#{userid}",
          {:client_message, :matchmaking, userid, {:match_cancelled, {state.queue_id, state.match_id}}}
        )
      end)

    # TODO: Parties
    state.teams
      |> Enum.filter(fn
        {userid, _age, _range, :user} -> Enum.member?(state.accepted_users, userid)
        _ -> false
      end)
      |> Matchmaking.re_add_users_to_queue(state.queue_id)

    # These will remove themselves from their queues
    (state.declined_users ++ state.pending_accepts)
      |> Enum.each(fn userid ->
        PubSub.broadcast(
          Central.PubSub,
          "teiserver_client_messages:#{userid}",
          {:client_message, :matchmaking, userid, {:match_declined, {state.queue_id, state.match_id}}}
        )
      end)

    DynamicSupervisor.terminate_child(Teiserver.Game.QueueSupervisor, self())
    {:noreply, state}
  end

  # Try to setup a battle with the players currently readied up
  defp try_setup_lobby(state), do: {:noreply, state}
  defp try_setup_lobby_old(state) do
    # Send out the new battle stuff
    empty_battle = Lobby.find_empty_battle(fn l -> String.contains?(l.name, "EU ") end)

    case empty_battle do
      nil ->
        Logger.info("QueueMatchServer try_setup_lobby no empty battle")
        %{state | finding_battle: true}

      battle ->
        Logger.info("QueueMatchServer try_setup_lobby found empty battle")
        state.accepted_users
        |> Enum.each(fn userid ->
          Lobby.remove_user_from_any_battle(userid)

          PubSub.broadcast(
            Central.PubSub,
            "teiserver_client_messages:#{userid}",
            {:client_message, :matchmaking, userid, {:join_lobby, battle.id}}
          )
        end)

        midway_state = remove_players(state, state.accepted_users)

        # Coordinator sets up the battle
        Logger.info("QueueMatchServer try_setup_lobby starting battle setup")
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
        Logger.info("QueueMatchServer try_setup_lobby putting players on teams")
        [p1, p2 | _] = state.accepted_users
        Coordinator.cast_consul(battle.id, %{command: "change-battlestatus", remaining: p1, senderid: Coordinator.get_coordinator_userid(),
          status: %{
            player_number: 0,
            team_number: 0,
            player: true,
            bonus: 0,
            ready: true
          }
        })
        Coordinator.cast_consul(battle.id, %{command: "change-battlestatus", remaining: p2, senderid: Coordinator.get_coordinator_userid(),
          status: %{
            player_number: 1,
            team_number: 1,
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
            Logger.info("QueueMatchServer try_setup_lobby cannot start as not all are players")
            Lobby.sayex(Coordinator.get_coordinator_userid, "Unable to start the lobby as one or more of the matched users are not a player. Please rejoin the queue and try again.", battle.id)

            battle = Lobby.get_lobby(battle.id)
            new_tags = Map.drop(battle.tags, ["server/match/queue_id"])
            Lobby.set_script_tags(battle.id, new_tags)

          all_synced == false ->
            Logger.info("QueueMatchServer try_setup_lobby cannot start as not all are synced")
            Lobby.sayex(Coordinator.get_coordinator_userid, "Unable to start the lobby as one or more of the matched players are unsynced. Please rejoin the queue and try again.", battle.id)

            battle = Lobby.get_lobby(battle.id)
            new_tags = Map.drop(battle.tags, ["server/match/queue_id"])
            Lobby.set_script_tags(battle.id, new_tags)

          true ->
            Logger.info("QueueMatchServer try_setup_lobby calling player cv start")
            Lobby.sayex(Coordinator.get_coordinator_userid, "Attempting to start the game, if this doesn't work feel free to start it yourselves and report to Teifion.", battle.id)
            :timer.sleep(100)
            Lobby.say(p1, "!cv forcestart", battle.id)
            :timer.sleep(100)
            Lobby.say(p2, "!y", battle.id)
            :timer.sleep(100)

            # Logger.info("QueueMatchServer try_setup_lobby calling forcestart")
            # Coordinator.send_to_host(empty_battle.id, "!forcestart")
            :timer.sleep(100)

            PubSub.broadcast(
              Central.PubSub,
              "teiserver_queue_wait:#{state.id}",
              {:queue_match, :match_made, state.id, battle.id}
            )
        end

        %{
          midway_state
          | finding_battle: false,
            matched_players: [],
            pending_accepts: [],
            ready_started_at: nil,
            accepted_users: []
        }
    end
  end

  @spec start_link(List.t()) :: :ignore | {:error, any} | {:ok, pid}
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts[:data], [])
  end

  @impl true
  @spec init(Map.t()) :: {:ok, Map.t()}
  def init(opts) do
    db_queue = Matchmaking.get_queue(opts.queue_id)

    :timer.send_interval(db_queue.settings["ready_tick_interval"] || @tick_interval, self(), :tick)
    :timer.send_after(db_queue.settings["ready_wait_time"] || @ready_wait_time, :end_waiting)

    # Update the queue pids cache to point to this process
    Horde.Registry.register(
      Teiserver.ServerRegistry,
      "QueueMatchServer:#{opts.match_id}",
      opts.match_id
    )

    PubSub.broadcast(
      Central.PubSub,
      "teiserver_queue_match:#{opts.queue_id}",
      {:queue_wait, :match_attempt, opts.queue_id, opts.match_id}
    )

    # TODO: Have this be a PartyLib function, to extract userids from party_ids
    users = opts.teams
      |> List.flatten
      |> Enum.map(fn
        {party_id, _time, _range, :party} ->
          # FIXME: at the time of writing there is no party functionality in place
          party_id

        {userid, _time, _range, :user} ->
          userid
      end)

    state = %{
      match_id: opts.match_id,
      queue_id: opts.queue_id,
      teams: opts.teams,
      users: users,

      pending_accepts: users,
      accepted_users: [],
      declined_users: []
    }

    send_invites(state)

    {:ok, state}
  end
end
