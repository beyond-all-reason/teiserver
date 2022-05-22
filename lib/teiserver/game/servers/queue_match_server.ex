defmodule Teiserver.Game.QueueMatchServer do
  use GenServer
  require Logger
  alias Teiserver.Battle.Lobby
  alias Teiserver.Data.Matchmaking
  alias Phoenix.PubSub
  alias Teiserver.{Coordinator, Client, Telemetry}

  @tick_interval 500
  @ready_wait_time 15_000

  @impl true
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
              find_empty_lobby(interim_state)

            # Not ready quite yet, still waiting for 1 or more others
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

  def handle_info(:tick, %{stage: "Completed"} = state) do
    {:noreply, state}
  end

  def handle_info(:tick, %{stage: "Setting up lobby"} = state) do
    {:noreply, setup_lobby(state)}
  end

  def handle_info(:tick, %{stage: "Finding empty lobby"} = state) do
    {:noreply, find_empty_lobby(state)}
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

  @spec find_empty_lobby(map()) :: map()
  defp find_empty_lobby(state) do
    empty_lobby = Lobby.find_empty_lobby(fn l -> String.contains?(l.name, "EU ") end)

    case empty_lobby do
      nil ->
        Logger.info("QueueMatchServer #{state.match_id} find_empty_lobby was unable to find an empty lobby")
        # TODO: Use the coordinator to request a new lobby be hosted by SPADS
        %{state | stage: "Finding empty lobby"}

      _ ->
        Logger.info("QueueMatchServer #{state.match_id} find_empty_lobby found empty lobby")
        setup_lobby(%{state | lobby_id: empty_lobby.id})
    end
  end

  # Try to setup a battle with the players currently readied up
  def setup_lobby(%{lobby_id: nil} = state), do: find_empty_lobby(state)
  def setup_lobby(state) do
    lobby = state.lobby_id
      |> Lobby.get_lobby()
      |> Lobby.silence_lobby()

    state.users
      |> Enum.each(fn userid ->
        Lobby.force_add_user_to_battle(userid, lobby.id)
      end)

    # Coordinator sets up the battle
    Logger.info("QueueMatchServer #{state.match_id} setup_lobby starting battle setup")
    map_name = state.db_queue.map_list |> Enum.random()

    [
      "!preset team",
      "!bset startpostype 2",
      "!autobalance off",
      "!map #{map_name}"
    ]
      |> Enum.each(fn cmd ->
        Coordinator.send_to_host(lobby.id, cmd)
        :timer.sleep(100)
      end)

    # Now put the players on their teams, for now we're assuming every game is just a 1v1
    Logger.info("QueueMatchServer #{state.match_id} setup_lobby putting players on teams")
    [p1, p2 | _] = state.users
    Coordinator.cast_consul(lobby.id, %{command: "change-battlestatus", remaining: p1, senderid: Coordinator.get_coordinator_userid(),
      status: %{
        player_number: 0,
        team_number: 0,
        player: true,
        bonus: 0,
        ready: true
      }
    })
    Coordinator.cast_consul(lobby.id, %{command: "change-battlestatus", remaining: p2, senderid: Coordinator.get_coordinator_userid(),
      status: %{
        player_number: 1,
        team_number: 1,
        player: true,
        bonus: 0,
        ready: true
      }
    })

    # Update the lobby itself
    lobby = Lobby.get_lobby(lobby.id)
    new_tags = Map.merge(lobby.tags, %{
      "server/match/match_id" => state.match_id,
      "server/match/queue_id" => state.queue_id
    })
    Lobby.set_script_tags(lobby.id, new_tags)

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
        Logger.info("QueueMatchServer #{state.match_id} setup_lobby cannot start as not all are players")
        Lobby.sayex(Coordinator.get_coordinator_userid, "Unable to start the lobby as one or more of the matched users are not a player. Please rejoin the queue and try again.", lobby.id)

        new_tags = Map.drop(lobby.tags, ["server/match/match_id", "server/match/queue_id"])
        Lobby.set_script_tags(lobby.id, new_tags)

      all_synced == false ->
        Logger.info("QueueMatchServer #{state.match_id} setup_lobby cannot start as not all are synced")
        Lobby.sayex(Coordinator.get_coordinator_userid, "Unable to start the lobby as one or more of the matched players are unsynced. Please rejoin the queue and try again.", lobby.id)

        new_tags = Map.drop(lobby.tags, ["server/match/match_id", "server/match/queue_id"])
        Lobby.set_script_tags(lobby.id, new_tags)

      true ->
        Logger.info("QueueMatchServer #{state.match_id} setup_lobby calling player cv start")
        Lobby.sayex(Coordinator.get_coordinator_userid, "Attempting to start the game, if this doesn't work feel free to start it yourselves and report to Teifion.", lobby.id)

        :timer.sleep(100)
        Lobby.say(p1, "testing: !cv forcestart", lobby.id)
        :timer.sleep(100)
        Lobby.say(p2, "testing: !y", lobby.id)
        :timer.sleep(100)

        Logger.info("QueueMatchServer #{state.match_id} setup_lobby calling forcestart")
        Coordinator.send_to_host(lobby.id, "!forcestart")
        :timer.sleep(100)

        PubSub.broadcast(
          Central.PubSub,
          "teiserver_queue_wait:#{state.queue_id}",
          {:queue_match, :match_made, state.id, lobby.id}
        )
    end

    self_pid = self()
    spawn(fn ->
      :timer.sleep(5_000)
      DynamicSupervisor.terminate_child(Teiserver.Game.QueueSupervisor, self_pid)
    end)
    %{state | stage: "Completed"}
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
      db_queue: db_queue,
      teams: opts.teams,
      users: users,

      stage: "accepting",
      lobby_id: nil,

      pending_accepts: users,
      accepted_users: [],
      declined_users: []
    }

    send_invites(state)

    {:ok, state}
  end
end
