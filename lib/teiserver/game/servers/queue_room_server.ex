defmodule Teiserver.Game.QueueRoomServer do
  @moduledoc """
  This server takes the players who are matched together and finds them a
  room to play in. It (if the setting is enabled) also handles readying up
  for the game.
  """

  use GenServer
  require Logger
  alias Teiserver.{Lobby, Battle, Config}
  alias Teiserver.Battle.{BalanceLib}
  alias Teiserver.Data.{Matchmaking, QueueGroup}
  alias Phoenix.PubSub
  alias Teiserver.{Account, Coordinator, Battle}

  @tick_interval 500
  @ready_wait_time 30_000
  @find_timeout 5_000

  @impl true
  def handle_cast({:player_accept, player_id}, state) when is_integer(player_id) do
    Logger.info("QueueRoomServer #{state.match_id} player accept #{player_id}")

    new_state =
      case player_id in state.pending_accepts do
        true ->
          new_pending_accepts = List.delete(state.pending_accepts, player_id)

          interim_state = %{
            state
            | pending_accepts: new_pending_accepts,
              accepted_users: [player_id | state.accepted_users]
          }

          case Enum.empty?(new_pending_accepts) do
            # That was the last one, go-time
            true ->
              if Enum.empty?(state.declined_users) do
                find_empty_lobby(interim_state)
              else
                Logger.info(
                  "QueueRoomServer cancel_match #{state.match_id} because one or more declined users"
                )

                cancel_match(interim_state)
              end

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
    Logger.info("QueueRoomServer #{state.match_id} player decline #{player_id}")

    new_state = %{
      state
      | pending_accepts: List.delete(state.pending_accepts, player_id),
        declined_users: [player_id | state.declined_users]
    }

    {:noreply, new_state}
  end

  @impl true
  def handle_info(:initial_setup, state) do
    db_queue = Matchmaking.get_queue(state.queue_id)

    :timer.send_interval(
      db_queue.settings["ready_tick_interval"] || @tick_interval,
      self(),
      :tick
    )

    :timer.send_after(db_queue.settings["ready_wait_time"] || @ready_wait_time, :end_waiting)

    balance = balance_groups(state.group_list, db_queue)
    teams = balance.team_players

    new_state = %{state | balance: balance, teams: teams, db_queue: db_queue}

    {:noreply, new_state}
  end

  def handle_info(:end_waiting, state) do
    Logger.info(
      "QueueRoomServer match cancelled #{state.match_id} because :end_waiting, state: #{inspect(state)}"
    )

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
    Logger.info(
      "QueueRoomServer match cancelled #{state.match_id} because ticked and no pending accepts"
    )

    cancel_match(state)
  end

  # We have pending accepts, the tick does nothing
  def handle_info(:tick, state) do
    {:noreply, state}
  end

  # :find_timeout
  def handle_info(:find_timeout, %{stage: "Finding empty lobby"} = state) do
    Logger.info("QueueRoomServer match cancelled #{state.match_id} because find timeout")
    cancel_match(state)
  end

  def handle_info(:find_timeout, state) do
    {:noreply, state}
  end

  def handle_info({:update, :settings, new_list}, state),
    do: {:noreply, %{state | settings: new_list}}

  def handle_info({:update, :map_list, new_list}, state),
    do: {:noreply, %{state | map_list: new_list}}

  defp send_invites(%{user_ids: user_ids} = state) do
    user_ids
    |> Enum.map(fn userid ->
      PubSub.broadcast(
        Teiserver.PubSub,
        "teiserver_client_messages:#{userid}",
        %{
          channel: "teiserver_client_messages:#{userid}",
          event: :matchmaking,
          sub_event: :match_ready,
          queue_id: state.queue_id,
          match_id: state.match_id
        }
      )
    end)
  end

  defp cancel_match(state) do
    # If any of a group didn't accept, the group isn't getting re-added
    accepted_groups =
      state.group_list
      |> Enum.filter(fn group ->
        group.members
        |> Enum.map(fn userid ->
          Enum.member?(state.accepted_users, userid)
        end)
        |> Enum.all?()
      end)
      |> Enum.map(fn group -> group.id end)

    # Message the relevant members the match is cancelled
    state.group_list
    |> Enum.filter(fn group -> Enum.member?(accepted_groups, group.id) end)
    |> Enum.map(fn group -> group.members end)
    |> List.flatten()
    |> Enum.each(fn userid ->
      PubSub.broadcast(
        Teiserver.PubSub,
        "teiserver_client_messages:#{userid}",
        %{
          channel: "teiserver_client_messages:#{userid}",
          event: :matchmaking,
          sub_event: :match_cancelled,
          queue_id: state.queue_id,
          match_id: state.match_id
        }
      )
    end)

    # The others can know it got declined
    state.group_list
    |> Enum.reject(fn group -> Enum.member?(accepted_groups, group.id) end)
    |> Enum.map(fn group -> group.members end)
    |> List.flatten()
    |> Enum.each(fn userid ->
      Account.remove_client_from_all_queues(userid)

      PubSub.broadcast(
        Teiserver.PubSub,
        "teiserver_client_messages:#{userid}",
        %{
          channel: "teiserver_client_messages:#{userid}",
          event: :matchmaking,
          sub_event: :match_declined,
          queue_id: state.queue_id,
          match_id: state.match_id
        }
      )
    end)

    # Now message the QueueWaitServers to let them know what's up
    PubSub.broadcast(
      Teiserver.PubSub,
      "teiserver_global_matchmaking",
      %{
        channel: "teiserver_global_matchmaking",
        event: :resume_search,
        groups: accepted_groups
      }
    )

    declined_groups =
      state.group_list
      |> Enum.map(fn group -> group.id end)
      |> Enum.reject(fn group_id ->
        Enum.member?(accepted_groups, group_id)
      end)

    PubSub.broadcast(
      Teiserver.PubSub,
      "teiserver_global_matchmaking",
      %{
        channel: "teiserver_global_matchmaking",
        event: :cancel_search,
        groups: declined_groups
      }
    )

    Logger.info("QueueRoomServer match cancelled #{state.match_id}")
    DynamicSupervisor.terminate_child(Teiserver.Game.QueueSupervisor, self())
    {:noreply, state}
  end

  @spec find_empty_lobby(map()) :: map()
  defp find_empty_lobby(state) do
    empty_lobby =
      Lobby.find_empty_lobby(fn l ->
        String.starts_with?(l.name, "EU ") or String.starts_with?(l.name, "BH ")
      end)

    case empty_lobby do
      nil ->
        Logger.info(
          "QueueRoomServer #{state.match_id} find_empty_lobby was unable to find an empty lobby"
        )

        # TODO: Use the coordinator to request a new lobby be hosted by SPADS
        %{state | stage: "Finding empty lobby"}

      _ ->
        Logger.info("QueueRoomServer #{state.match_id} find_empty_lobby found empty lobby")
        setup_lobby(%{state | lobby_id: empty_lobby.id})
    end
  end

  # Try to setup a battle with the players currently readied up
  def setup_lobby(%{lobby_id: nil} = state), do: find_empty_lobby(state)

  def setup_lobby(state) do
    # First we want to go and remove the players from their game
    state.user_ids
    |> Enum.each(fn userid ->
      client = Account.get_client_by_id(userid)

      if client != nil and client.lobby_id do
        Coordinator.send_to_host(client.lobby_id, "!gkick #{client.name}")
      end
    end)

    lobby =
      state.lobby_id
      |> Lobby.get_lobby()

    Lobby.silence_lobby(state.lobby_id)
    Lobby.lock_lobby(state.lobby_id)
    Battle.rename_lobby(state.lobby_id, "Matchmaking #{state.db_queue.name}", nil)

    # Wait for all the kicks to take place, then move people
    :timer.sleep(1000)

    # Cancel the searches for the groups
    canceled_groups =
      state.group_list
      |> Enum.map(fn group -> group.id end)

    PubSub.broadcast(
      Teiserver.PubSub,
      "teiserver_global_matchmaking",
      %{
        channel: "teiserver_global_matchmaking",
        event: :cancel_search,
        groups: canceled_groups
      }
    )

    state.user_ids
    |> Enum.each(fn userid ->
      Lobby.force_add_user_to_lobby(userid, lobby.id)
    end)

    # Coordinator sets up the battle
    Logger.info("QueueRoomServer #{state.match_id} setup_lobby starting battle setup")
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

    Logger.info("QueueRoomServer #{state.match_id} setup_lobby putting players on teams")

    state.teams
    |> Enum.map(fn {team_id, team_members} ->
      team_members
      |> Enum.map(fn userid ->
        {team_id, userid}
      end)
    end)
    |> List.flatten()
    |> Enum.with_index()
    |> Enum.each(fn {{team_id, userid}, index} ->
      Coordinator.cast_consul(lobby.id, %{
        command: "change-battlestatus",
        remaining: userid,
        senderid: Coordinator.get_coordinator_userid(),
        status: %{
          player_number: index,
          team_number: team_id - 1,
          player: true,
          bonus: 0,
          ready: true
        }
      })
    end)

    # Update the modoptions
    Battle.set_modoptions(lobby.id, %{
      "server/match/match_id" => state.match_id,
      "server/match/queue_id" => state.queue_id
    })

    # Give things time to propagate before we start
    :timer.sleep(1000)

    all_clients = Account.get_clients(state.user_ids)

    all_players =
      all_clients
      |> Enum.map(fn c -> c != nil and c.player == true end)
      |> Enum.all?()

    all_synced =
      all_clients
      |> Enum.map(fn c -> c != nil and c.sync == %{engine: 1, game: 1, map: 1} end)
      |> Enum.all?()

    # First player in calls commands, the others okay them
    [first | others] = state.user_ids

    cond do
      all_players == false ->
        Logger.info(
          "QueueRoomServer #{state.match_id} setup_lobby cannot start as not all are players #{inspect(all_clients)}"
        )

        Lobby.sayex(
          Coordinator.get_coordinator_userid(),
          "Unable to start the lobby as one or more of the matched users are not a player. Please rejoin the queue and try again.",
          lobby.id
        )

        Battle.remove_modoptions(lobby.id, ["server/match/match_id", "server/match/queue_id"])

      all_synced == false ->
        Logger.info(
          "QueueRoomServer #{state.match_id} setup_lobby cannot start as not all are synced #{inspect(all_clients)}"
        )

        Lobby.sayex(
          Coordinator.get_coordinator_userid(),
          "Unable to start the lobby as one or more of the matched players are unsynced. Please rejoin the queue and try again.",
          lobby.id
        )

        Battle.remove_modoptions(lobby.id, ["server/match/match_id", "server/match/queue_id"])

      true ->
        Logger.info("QueueRoomServer #{state.match_id} setup_lobby calling player cv start")

        Lobby.sayex(
          Coordinator.get_coordinator_userid(),
          "Attempting to start the game, if this doesn't work feel free to start it yourselves and report the error to the devs.",
          lobby.id
        )

        :timer.sleep(100)

        Lobby.say(first, "!cv forcestart", lobby.id)
        :timer.sleep(100)

        others
        |> Enum.each(fn other_id ->
          Lobby.say(other_id, "!y", lobby.id)
          :timer.sleep(100)
        end)

        Logger.info("QueueRoomServer #{state.match_id} setup_lobby calling forcestart")
        Coordinator.send_to_host(lobby.id, "!forcestart")
        :timer.sleep(100)

        all_clients
        |> Enum.each(fn %{userid: userid} ->
          PubSub.broadcast(
            Teiserver.PubSub,
            "teiserver_client_messages:#{userid}",
            %{
              channel: "teiserver_client_messages:#{userid}",
              event: :matchmaking,
              sub_event: :match_created,
              queue_id: state.queue_id,
              match_id: state.match_id
            }
          )
        end)

        PubSub.broadcast(
          Teiserver.PubSub,
          "teiserver_queue:#{state.queue_id}",
          %{
            channel: "teiserver_queue:#{state.queue_id}",
            event: :match_made,
            queue_id: state.queue_id,
            lobby_id: lobby.id
          }
        )
    end

    self_pid = self()

    spawn(fn ->
      :timer.sleep(5_000)
      DynamicSupervisor.terminate_child(Teiserver.Game.QueueSupervisor, self_pid)
    end)

    %{state | stage: "Completed"}
  end

  @spec balance_groups([QueueGroup.t()], map()) :: map()
  defp balance_groups(group_list, db_queue) do
    balance_groups =
      group_list
      |> Enum.map(fn group ->
        group.members
        |> Map.new(fn userid ->
          {userid, group.rating}
        end)
      end)

    # Massive boundaries mean it will always keep parties together
    opts = [
      max_deviation: 1000,
      rating_lower_boundary: 1000,
      rating_upper_boundary: 1000,
      mean_diff_max: 1000,
      stddev_diff_max: 1000
    ]

    BalanceLib.create_balance(balance_groups, db_queue.team_count, opts)
  end

  @spec start_link(List.t()) :: :ignore | {:error, any} | {:ok, pid}
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts[:data], [])
  end

  @impl true
  @spec init(map()) :: {:ok, map()}
  def init(opts) do
    send(self(), :initial_setup)
    Process.send_after(self(), :find_timeout, @find_timeout)
    Logger.metadata(request_id: "QueueRoomServer##{opts.queue_id}/#{opts.match_id}")

    # Update the queue pids cache to point to this process
    Horde.Registry.register(
      Teiserver.QueueMatchRegistry,
      opts.match_id,
      opts.match_id
    )

    PubSub.broadcast(
      Teiserver.PubSub,
      "teiserver_queue:#{opts.queue_id}",
      %{
        channel: "teiserver_queue:#{opts.queue_id}",
        event: :match_attempt,
        queue_id: opts.queue_id,
        match_id: opts.match_id
      }
    )

    user_ids =
      opts.group_list
      |> Enum.map(fn g -> g.members end)
      |> List.flatten()

    state = %{
      match_id: opts.match_id,
      queue_id: opts.queue_id,
      group_list: opts.group_list,
      user_ids: user_ids,

      # Will get assigned during :initial_setup
      db_queue: nil,
      teams: nil,
      balance: nil,
      stage: "accepting",
      lobby_id: nil,
      pending_accepts: user_ids,
      accepted_users: [],
      declined_users: []
    }

    final_state =
      if Config.get_site_config_cache("matchmaking.Use ready check") == true do
        send_invites(state)

        Logger.info(
          "QueueRoomServer #{state.match_id} created, sent invites to #{inspect(user_ids)}"
        )

        state
      else
        Logger.info(
          "QueueRoomServer #{state.match_id} created, accepting all users #{inspect(user_ids)} as 'matchmaking.Use ready check' is false"
        )

        %{state | pending_accepts: [], accepted_users: user_ids, stage: "Finding empty lobby"}
      end

    {:ok, final_state}
  end
end
