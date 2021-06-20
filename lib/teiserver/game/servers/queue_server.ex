defmodule Teiserver.Game.QueueServer do
  use GenServer
  require Logger
  alias Teiserver.Battle.BattleLobby
  alias Phoenix.PubSub
  alias Teiserver.Director

  @default_tick_interval 5_000

  @ready_wait_time 15

  # TODO - Convert this into a system where each match is a new process and the match can
  # tell the queue server to either re-add the players to the pool or remove them (as the match is going ahead)
  # currently as the queues get bigger they'll stall waiting for players to ready up but
  # it's good enough for now
  def handle_call(:get_state, _from, state) do
    {:reply, state, state}
  end

  def handle_call({:add_player, userid, pid}, _from, state) when is_integer(userid) do
    {resp, new_state} =
      case Enum.member?(state.unmatched_players ++ state.matched_players, userid) do
        true ->
          {:duplicate, state}

        false ->
          player_item = %{
            join_time: :erlang.system_time(:seconds),
            pid: pid
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
            {:add_player, userid}
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
            {:remove_player, userid}
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

  def handle_info(:tick, state) do
    # Typically we need to check things like team size and the like
    # but for this test of concept stage we're going to just assume we need two players

    new_state =
      cond do
        # Trying to find a battle, not doing standard tick stuff
        state.finding_battle == true ->
          try_setup_battle(state)

        # This means we are not waiting for players, we can instead find some
        state.ready_started_at == nil ->
          # First make sure we have enough players...
          if Enum.count(state.unmatched_players) >= 2 and state.waiting_for_players == [] and
               state.players_accepted == [] do
            # Now grab the players
            [p1, p2 | new_unmatched_players] = Enum.reverse(state.unmatched_players)
            player1 = state.player_map[p1]
            player2 = state.player_map[p2]

            # Count them as matched up
            new_matched_players = [p1, p2 | state.matched_players]

            # Send them ready up commands
            send(player1.pid, {:matchmaking, {:match_ready, state.id}})
            send(player2.pid, {:matchmaking, {:match_ready, state.id}})

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
    empty_battle = BattleLobby.find_empty_battle()

    case empty_battle do
      nil ->
        %{state | finding_battle: true}

      battle ->
        state.players_accepted
        |> Enum.each(fn userid ->
          player = state.player_map[userid]
          send(player.pid, {:matchmaking, {:join_battle, battle.id}})
        end)

        midway_state = remove_players(state, state.players_accepted)

        # Director sets up the battle
        map_name = state.map_list |> Enum.random()
        BattleLobby.start_director_mode(battle.id)
        Director.cast_consul(battle.id, %{command: "manual-autohost", senderid: state.coordinator_id})
        Director.cast_consul(battle.id, %{command: "change-map", remaining: map_name, senderid: state.coordinator_id})

        # Now put the players on their teams, for now we're assuming every game is just a 1v1
        [p1, p2] = state.players_accepted
        Director.cast_consul(battle.id, %{command: "change-battlestatus", target_id: p1, senderid: state.coordinator_id,
          status: %{
            team_number: 0,
            ally_team_number: 0,
            player: true,
            bonus: 0,
            ready: true
          }
        })
        Director.cast_consul(battle.id, %{command: "change-battlestatus", target_id: p2, senderid: state.coordinator_id,
          status: %{
            team_number: 1,
            ally_team_number: 1,
            player: true,
            bonus: 0,
            ready: true
          }
        })

        # Give things time to propogate before we start
        :timer.sleep(250)
        Director.cast_consul(battle.id, %{command: "forcestart", senderid: state.coordinator_id})

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

  @spec init(Map.t()) :: {:ok, Map.t()}
  def init(opts) do
    tick_interval = Map.get(opts.queue.settings, "tick_interval", @default_tick_interval)
    :timer.send_interval(tick_interval, self(), :tick)

    # Update the queue pids cache to point to this process
    ConCache.put(:teiserver_queue_pids, opts.queue.id, self())

    {:ok,
     %{
       # Match ready stuff
       waiting_for_players: [],
       players_accepted: [],
       ready_started_at: nil,
       finding_battle: false,
       matchups: [],
       matched_players: [],
       unmatched_players: [],
       player_count: 0,
       player_map: %{},
       last_wait_time: 0,
       id: opts.queue.id,
       coordinator_id: Director.get_coordinator_userid(),
       team_size: opts.queue.team_size,
       map_list: opts.queue.map_list,
       settings: opts.queue.settings,
       ready_wait_time: opts.queue.settings["ready_wait_time"] || @ready_wait_time
     }}
  end
end
