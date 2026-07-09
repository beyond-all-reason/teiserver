defmodule Teiserver.TachyonLobby.Lobby do
  @moduledoc """
  Represent a single lobby
  """

  # This module has essentially 3 parts:
  # 1: the external API as usual. A set of exported function that delegate to
  # gen_statem.cast/call and so on
  # 2: the internal handlers: the callbacks for gen_statem
  # 3: an event sourcing system for the handlers.
  #
  # The handlers are responsible to check if the operation is valid, and then
  # translate the operation into an event. All events are structs that implement
  # a protocol to compute the next aggregate.
  # This aggregate is used to
  # 1: compute the end state after applying the original operation/event See process_events/2
  # 2: the update events to send to lobby members. See broadcast_updates/1
  # 3: update the lobby list process when relevant. Also handled in broadcast_updates/1
  #
  # The event sourcing approach is used so we can have some "atomic" operations, and more
  # complex operations can be represented through them. It is mostly useful when dealing
  # with player movements, to/from spectators or within ally teams.
  # It also handles update events without having to dispatch them manually on a case by
  # case basis.

  alias Plug.Crypto
  alias Teiserver.Account.User
  alias Teiserver.Autohost
  alias Teiserver.Autohost.Types, as: AT
  alias Teiserver.Cluster
  alias Teiserver.Helpers.Collections
  alias Teiserver.Helpers.MonitorCollection, as: MC
  alias Teiserver.Helpers.PubSubHelper
  alias Teiserver.KvStore
  alias Teiserver.Lobby.LobbyLib
  alias Teiserver.Messaging
  alias Teiserver.Player
  alias Teiserver.Tachyon
  alias Teiserver.TachyonBattle
  alias Teiserver.TachyonLobby.Event
  alias Teiserver.TachyonLobby.Events
  alias Teiserver.TachyonLobby.ListMonitor
  alias Teiserver.TachyonLobby.Registry, as: LobbyRegistry
  alias Teiserver.TachyonLobby.Supervisor, as: LobbySupervisor
  # lobby types
  alias Teiserver.TachyonLobby.Types, as: LT

  require Logger

  @behaviour :gen_statem

  # Note[sparse_map_for_update]
  # do not turn this into a struct!
  # at time of writing this comment, none of the properties can be removed, but there is
  # no guarantee that this will stay this way.
  # There is a semantic difference between %{foo: nil} and %{} (foo is not present).
  # `foo: nil` means that the property should be removed, but if the key is absent then
  # nothing changes. If that becomes a struct, then all keys are present by default, and
  # we lose the ability to tell the difference
  @typedoc """
  sparse map of everything that can be changed for a given bot
  """
  @type bot_update_data :: %{
          required(:id) => String.t(),
          optional(:name) => String.t(),
          optional(:short_name) => String.t(),
          optional(:version) => String.t(),
          optional(:options) => %{String.t() => String.t()}
        }

  @spec gen_id() :: LT.Types.id()
  def gen_id, do: UUID.uuid4()

  @default_call_timeout 5000

  def list_topic, do: "teiserver_tachyonlobby_list"

  @spec get_details(LT.Types.id()) :: {:ok, LT.Details.t()} | {:error, reason :: term()}
  def get_details(id) do
    call_lobby(id, :get_details)
  end

  def child_spec({lobby_id, _init_type} = args) do
    %{
      id: via_tuple(lobby_id),
      start: {__MODULE__, :start_link, [args]},
      restart: :temporary
    }
  end

  @spec start_link({LT.Types.id(), {:user, LT.StartParams.t()} | {:snapshot, binary()}}) ::
          GenServer.on_start()
  def start_link({id, _data} = args) do
    via_tuple(id) |> :gen_statem.start_link(__MODULE__, args, [])
  end

  @doc """
  this is meant to propagate event processing across replicas and shouldn't
  be called from other modules
  """
  def apply_events(lobby_id, events, opts) do
    call_lobby(lobby_id, {:apply_events, events, opts}, to_primary?: false)
  end

  @spec join(LT.Types.id(), LT.PlayerJoinData.t(), pid()) ::
          {:ok, lobby_pid :: pid(), LT.Details.t()}
          | {:error, :banned, ban_until :: DateTime.t()}
          | {:error, reason :: term()}
  def join(lobby_id, %LT.PlayerJoinData{} = join_data, pid \\ self()) do
    call_lobby(lobby_id, {:join, join_data, pid})
  end

  @spec leave(LT.Types.id(), User.id()) :: :ok | {:error, reason :: :lobby_full | term()}
  def leave(lobby_id, user_id) do
    via_tuple(lobby_id) |> :gen_statem.call({:leave, user_id}, @default_call_timeout)
  catch
    :exit, {:noproc, _details} -> {:error, :invalid_lobby}
    # lobby shutting down would result in the player leaving anyway
    :exit, {:shutdown, _reason} -> :ok
  end

  @spec join_ally_team(LT.Types.id(), User.id(), allyTeam :: non_neg_integer()) ::
          {:ok, LT.Details.t()}
          | {:error,
             reason :: :invalid_lobby | :not_in_lobby | :invalid_ally_team | :ally_team_full}
  def join_ally_team(lobby_id, user_id, ally_team) do
    call_lobby(lobby_id, {:join_ally_team, user_id, ally_team})
  end

  @spec spectate(LT.Types.id(), User.id()) :: :ok | {:error, :invalid_lobby | :not_in_lobby}
  def spectate(lobby_id, user_id) do
    call_lobby(lobby_id, {:spectate, user_id})
  end

  @doc """
  request to be added as a spectator to the battle being played
  """
  @spec join_battle(LT.Types.id(), User.id()) ::
          :ok | {:error, :invalid_lobby | :not_in_lobby | :invalid_battle | term()}
  def join_battle(lobby_id, user_id) do
    call_lobby(lobby_id, {:join_battle, user_id})
  end

  @spec rejoin(LT.Types.id(), User.id(), pid()) ::
          {:ok, lobby_pid :: pid(), LT.Details.t()} | {:error, :invalid_lobby}
  def rejoin(lobby_id, user_id, pid) do
    call_lobby(lobby_id, {:rejoin, user_id, pid})
  end

  @type client_status_update_data :: %{
          optional(:ready?) => boolean(),
          optional(:asset_status) => LT.Types.asset_status()
        }
  @spec update_client_status(LT.Types.id(), User.id(), client_status_update_data()) ::
          :ok | {:error, :invalid_lobby | :not_in_lobby | :not_a_player}
  def update_client_status(lobby_id, user_id, update_data) do
    call_lobby(lobby_id, {:update_client_status, user_id, update_data})
  end

  @type add_bot_opt ::
          {:name, String.t()} | {:version, String.t()} | {:options, %{String.t() => String.t()}}
  @type add_bot_opts :: [add_bot_opt]

  @spec add_bot(
          LT.Types.id(),
          User.id(),
          ally_team :: non_neg_integer(),
          short_name :: String.t(),
          add_bot_opts()
        ) :: {:ok, bot_id :: String.t()} | {:error, reason :: term()}
  def add_bot(
        lobby_id,
        user_id,
        ally_team,
        short_name,
        opts \\ []
      ) do
    call_lobby(
      lobby_id,
      {:add_bot, user_id,
       %{
         ally_team: ally_team,
         short_name: short_name,
         name: opts[:name],
         version: opts[:version],
         options: Keyword.get(opts, :options, %{})
       }}
    )
  end

  @spec remove_bot(LT.Types.id(), bot_id :: String.t()) ::
          :ok | {:error, :invalid_bot_id | term()}
  def remove_bot(lobby_id, bot_id) do
    call_lobby(lobby_id, {:remove_bot, bot_id})
  end

  @spec update_bot(LT.Types.id(), bot_update_data()) ::
          :ok | {:error, reason :: :invalid_bot_id | term()}
  def update_bot(lobby_id, update_data) do
    call_lobby(lobby_id, {:update_bot, update_data})
  end

  # See Note[sparse_map_for_update]
  @typedoc """
  sparse map of everything that can be changed for a given bot
  """
  @type lobby_update_data :: %{
          optional(:name) => String.t(),
          optional(:map_name) => String.t(),
          optional(:ally_team_config) => [LT.AllyTeamConfig.t()],
          optional(:game_options) => %{String.t() => String.t() | nil},
          optional(:tags) => %{String.t() => map() | nil}
        }

  @doc """
  Update lobby properties, like ally team config, names and whatnot
  """
  @spec update_properties(LT.Types.id(), User.id(), lobby_update_data()) ::
          :ok | {:error, :invalid_lobby | term()}
  def update_properties(lobby_id, user_id, update_data) do
    call_lobby(lobby_id, {:update_properties, user_id, update_data})
  end

  @spec vote_submit(LT.Types.id(), User.id(), {String.t(), LT.VoteState.vote_ballot()}) ::
          :ok | {:error, :invalid_lobby | :invalid_vote}
  def vote_submit(lobby_id, user_id, ballot) do
    call_lobby(lobby_id, {:vote_submit, user_id, ballot})
  end

  @spec send_message(LT.Types.id(), User.id(), String.t()) ::
          :ok | {:error, :invalid_request, reason :: term()}
  def send_message(lobby_id, from_id, msg_content) do
    call_lobby(lobby_id, {:send_message, from_id, msg_content})
  end

  @spec kickban(LT.Types.id(), User.id(), target_id :: User.id(), ban_until :: DateTime.t() | nil) ::
          :ok | {:error, :invalid_lobby | :not_in_lobby | :unauthorized | term()}
  def kickban(lobby_id, user_id, target_id, ban_until \\ nil) do
    call_lobby(lobby_id, {:kickban, user_id, target_id, ban_until})
  end

  @doc """
  This should only be used for tests, because there is some gnarly logic in
  generating the start script and it's a bit hard to test end to end
  """
  @spec get_start_script(LT.Types.id()) :: AT.StartScript.t()
  def get_start_script(lobby_id) do
    via_tuple(lobby_id) |> :gen_statem.call(:get_start_script, @default_call_timeout)
  end

  @spec join_queue(LT.Types.id(), User.id()) :: :ok | {:error, :invalid_lobby | :not_in_lobby}
  def join_queue(lobby_id, user_id) do
    call_lobby(lobby_id, {:join_queue, user_id})
  end

  @spec appoint_boss(LT.Types.id(), User.id(), appointee_id :: User.id()) ::
          :ok | {:error, :invalid_lobby | :not_in_lobby | :no_boss_allowed | :not_a_boss}
  def appoint_boss(lobby_id, user_id, appointee_id) do
    call_lobby(lobby_id, {:appoint_boss, user_id, appointee_id})
  end

  @spec unboss(LT.Types.id(), User.id(), boss_id :: User.id()) ::
          :ok | {:error, :invalid_lobby | :not_in_lobby | :no_boss_allowed | :not_a_boss}
  def unboss(lobby_id, user_id, boss_id) do
    call_lobby(lobby_id, {:unboss, user_id, boss_id})
  end

  @spec start_battle(LT.Types.id(), User.id()) ::
          :ok | {:error, reason :: :not_in_lobby | :battle_already_started | term()}
  def start_battle(lobby_id, user_id) do
    call_lobby(lobby_id, {:start_battle, user_id})
  end

  @doc """
  used only for testing
  """
  def trigger_vote_timeout(lobby_id, vote_id) do
    LobbyRegistry.lookup(lobby_id) |> send({:vote_timeout, vote_id})
  end

  @impl :gen_statem
  def callback_mode, do: :handle_event_function

  @impl :gen_statem
  @spec init({LT.Types.id(), {:user, LT.StartParams.t()} | {:snapshot, binary()}}) ::
          {:ok, term(), LT.Data.t()}
  def init({id, {:user, %LT.StartParams{} = start_params}}) do
    Process.flag(:trap_exit, true)
    Logger.metadata(actor_type: :lobby, actor_id: id)
    :net_kernel.monitor_nodes(true)

    monitors =
      MC.new() |> MC.monitor(start_params.creator_pid, {:user, start_params.creator_data.id})

    bosses =
      if start_params.boss_enabled?,
        do: MapSet.new([start_params.creator_data.id]),
        else: MapSet.new()

    state =
      %LT.Data{
        id: id,
        primary?: routing_key(id) |> Cluster.primary?(),
        monitors: monitors,
        name: start_params.name,
        map_name: start_params.map_name,
        game_version: start_params.game_version,
        engine_version: start_params.engine_version,
        boss_enabled?: start_params.boss_enabled?,
        bosses: bosses,
        ally_team_config: start_params.ally_team_config,
        game_options: start_params.game_options,
        tags: start_params.tags,
        players: %{
          start_params.creator_data.id => %LT.Player{
            id: start_params.creator_data.id,
            name: start_params.creator_data.name,
            password: gen_password(),
            pid: start_params.creator_pid,
            team: {0, 0, 0},
            ready?: false,
            asset_status: :complete
          }
        },
        spectators: %{},
        bot_idx_counter: 0,
        current_battle: nil,
        ids_to_rejoin: MapSet.new(),
        vote_idx: 1,
        current_vote: nil,
        vote_history: %{}
      }

    register_new_lobby(state)
    Logger.info("Lobby created by user #{start_params.creator_data.id}")
    {:ok, :running, state}
  end

  def init({id, {:snapshot, serialized_data}}) do
    Process.flag(:trap_exit, true)
    Logger.metadata(actor_type: :lobby, actor_id: id)
    Logger.debug("Restoring lobby from snapshot")
    :net_kernel.monitor_nodes(true)

    snapshot = Crypto.non_executable_binary_to_term(serialized_data, [:safe])

    player_ids =
      for {id, x} <- snapshot.players, !is_map_key(x, :host_user_id) do
        id
      end

    ids_to_rejoin =
      Enum.concat(player_ids, Map.keys(snapshot.spectators)) |> MapSet.new()

    data =
      snapshot
      |> Map.put(:monitors, MC.new())
      |> Map.put(:ids_to_rejoin, ids_to_rejoin)
      |> Map.put(:primary?, routing_key(id) |> Cluster.primary?())

    timeout = Tachyon.get_restoration_timeout()
    actions = [{:state_timeout, timeout, :snapshot_timeout}]

    {:ok, :starting_up, data, actions}
  end

  def init({id, {:replica, %LT.Data{} = data}}) do
    Process.flag(:trap_exit, true)
    Logger.metadata(actor_type: :lobby, actor_id: id)
    Logger.debug("Starting replica for lobby #{id}")
    :net_kernel.monitor_nodes(true)

    users = Map.values(data.players) ++ Map.values(data.spectators)

    monitors =
      Enum.reduce(users, MC.new(), fn user, monitors ->
        MC.monitor(monitors, user.pid, {:user, user.id})
      end)

    monitors =
      if data.current_battle do
        MC.monitor(monitors, data.current_battle.pid, :current_battle)
      else
        monitors
      end

    data = %{data | monitors: monitors, primary?: routing_key(id) |> Cluster.primary?()}
    register_new_lobby(data)
    {:ok, :running, data}
  end

  @impl :gen_statem
  def handle_event({:call, from}, :get_details, _state, %LT.Data{} = data) do
    {:keep_state, data, [{:reply, from, {:ok, get_details_from_state(data)}}]}
  end

  def handle_event({:call, from}, :get_overview, _state, %LT.Data{} = data) do
    {:keep_state, data, [{:reply, from, get_overview_from_state(data)}]}
  end

  def handle_event(
        {:call, from},
        {:rejoin, _user_id, _user_pid},
        state,
        %LT.Data{} = data
      )
      when state != :starting_up,
      do: {:keep_state, data, [{:reply, from, {:error, :invalid_lobby}}]}

  def handle_event(
        {:call, from},
        {:rejoin, user_id, user_pid},
        :starting_up,
        %LT.Data{} = data
      ) do
    if MapSet.member?(data.ids_to_rejoin, user_id) do
      ids_left = MapSet.delete(data.ids_to_rejoin, user_id)

      players =
        if is_map_key(data.players, user_id) do
          Map.update!(data.players, user_id, fn %LT.Player{} = p ->
            %{p | pid: user_pid}
          end)
        else
          data.players
        end

      spectators =
        if is_map_key(data.spectators, user_id) do
          Map.update!(data.spectators, user_id, fn %LT.Spectator{} = s ->
            %{s | pid: user_pid}
          end)
        else
          data.spectators
        end

      data =
        %{data | players: players, spectators: spectators, ids_to_rejoin: ids_left}
        |> Map.update!(:monitors, &MC.monitor(&1, user_pid, {:user, user_id}))

      actions = [{:reply, from, {:ok, self(), get_details_from_state(data)}}]

      if MapSet.size(ids_left) == 0 do
        Logger.debug("all member rejoined, start up completed")
        register_new_lobby(data)

        if data.current_vote != nil do
          diff = max(0, DateTime.diff(data.current_vote.until, DateTime.utc_now(), :millisecond))
          :timer.send_after(diff, {:vote_timeout, data.current_vote.id})
        end

        {:next_state, :running, data, actions}
      else
        {:keep_state, data, actions}
      end
    else
      {:keep_state, data, [{:reply, from, {:error, :invalid_lobby}}]}
    end
  end

  def handle_event({:call, _from}, _request, :starting_up, %LT.Data{} = data) do
    {:keep_state, data, [{:postpone, true}]}
  end

  def handle_event({:call, from}, _request, :shutting_down, %LT.Data{} = data) do
    {:keep_state, data, [{:reply, from, {:error, :shutting_down}}]}
  end

  def handle_event(
        {:call, from},
        {:join, %LT.PlayerJoinData{} = join_data, _pid},
        _state,
        %LT.Data{} = data
      )
      when is_map_key(data.players, join_data.id) or is_map_key(data.spectators, join_data.id) do
    {:keep_state, data, [{:reply, from, {:ok, self(), get_details_from_state(data)}}]}
  end

  def handle_event(
        {:call, from},
        {:join, %LT.PlayerJoinData{id: user_id} = join_data, pid},
        _state,
        %LT.Data{} = data
      )
      when is_map_key(data.banned_users, user_id) do
    ban_until = data.banned_users[user_id]

    if ban_expired?(ban_until) do
      data = update_in(data.banned_users, &Map.delete(&1, user_id))
      {:keep_state, data, [{:next_event, {:call, from}, {:join, join_data, pid}}]}
    else
      {:keep_state, data, [{:reply, from, {:error, :banned, ban_until}}]}
    end
  end

  # 251 is the (current) engine limit for specs + players + bots
  # we also need to enforce this limit on the battle itself, this is where
  # it's actually important. We could theoretically have more than 251
  # lobby members, but it would be rather awkward to only have a subset
  # then in the battle. It's overall simpler to also limit the lobby size
  # (though the members of the lobby may not be the one in the battle itself)
  def handle_event(
        {:call, from},
        {:join, _join_data, _pid},
        _state,
        %LT.Data{} = data
      )
      when map_size(data.spectators) + map_size(data.players) >= 251 do
    {:keep_state, data, [{:reply, from, {:error, :lobby_full}}]}
  end

  def handle_event(
        {:call, from},
        {:join, %LT.PlayerJoinData{} = join_data, pid},
        _state,
        %LT.Data{} = data
      ) do
    user_id = join_data.id

    spec_data = %LT.Spectator{
      id: user_id,
      name: join_data.name,
      password: gen_password(),
      pid: pid,
      join_queue_position: nil
    }

    events = [%Events.AddSpectator{spec: spec_data}]
    data = process_events(data, events, sender_id: user_id).data
    {:keep_state, data, [{:reply, from, {:ok, self(), get_details_from_state(data)}}]}
  end

  def handle_event({:call, from}, {:leave, user_id}, _state, %LT.Data{} = data)
      when is_map_key(data.players, user_id) do
    final_aggregate = remove_player_from_lobby(user_id, data)
    {:keep_state, final_aggregate.data, [{:reply, from, :ok} | final_aggregate.actions]}
  end

  def handle_event({:call, from}, {:leave, user_id}, _state, %LT.Data{} = data)
      when is_map_key(data.spectators, user_id) do
    final_aggregate = remove_spectator_from_lobby(user_id, data)
    {:keep_state, final_aggregate.data, [{:reply, from, :ok} | final_aggregate.actions]}
  end

  def handle_event({:call, from}, {:leave, _user_id}, _state, %LT.Data{} = data),
    do: {:keep_state, data, [{:reply, from, {:error, :not_in_lobby}}]}

  def handle_event(
        {:call, from},
        {:join_ally_team, user_id, _ally_team},
        _state,
        %LT.Data{} = data
      )
      when not is_map_key(data.players, user_id) and not is_map_key(data.spectators, user_id),
      do: {:keep_state, data, [{:reply, from, {:error, :not_in_lobby}}]}

  def handle_event(
        {:call, from},
        {:join_ally_team, user_id, _ally_team},
        _state,
        %LT.Data{} = data
      )
      when not is_map_key(data.players, user_id) and not is_map_key(data.spectators, user_id),
      do: {:keep_state, data, [{:reply, from, {:error, :not_in_lobby}}]}

  def handle_event(
        {:call, from},
        {:join_ally_team, _user_id, ally_team},
        _state,
        %LT.Data{} = data
      )
      when ally_team >= length(data.ally_team_config) or ally_team < 0,
      do: {:keep_state, data, [{:reply, from, {:error, :invalid_ally_team}}]}

  def handle_event(
        {:call, from},
        {:join_ally_team, user_id, ally_team},
        _state,
        %LT.Data{} = data
      ) do
    ally_team_capacity = Enum.at(data.ally_team_config, ally_team).max_teams

    in_team_count = team_count(ally_team, data.players)

    already_there? =
      case data.players[user_id] do
        nil -> false
        %{team: {at, _team, _player}} -> at == ally_team
      end

    cond do
      already_there? ->
        {:keep_state, data, [{:reply, from, {:ok, get_details_from_state(data)}}]}

      in_team_count >= ally_team_capacity ->
        {:keep_state, data, [{:reply, from, {:error, :ally_team_full}}]}

      true ->
        # we guarantee that teams are consecutive in the ally team (without gap)
        # so we can use the in_team_count as the index for the new team in the ally team
        team = {ally_team, in_team_count, 0}

        case {is_map_key(data.players, user_id), data.spectators[user_id]} do
          {true, nil} ->
            # we're moving a player from a different ally team
            events = [%Events.MovePlayer{player_id: user_id, team: team}]
            data = process_events(data, events).data

            {:keep_state, data, [{:reply, from, {:ok, get_details_from_state(data)}}]}

          {false, _s} ->
            # Adding a spec into an ally team. The way we construct the team
            # means it doesn't require any reshuffling of existing players
            events = [%Events.MoveSpecToPlayer{user_id: user_id, player_data: %{team: team}}]
            data = process_events(data, events).data

            {:keep_state, data, [{:reply, from, {:ok, get_details_from_state(data)}}]}
        end
    end
  end

  def handle_event({:call, from}, {:spectate, user_id}, _state, %LT.Data{} = data)
      when not is_map_key(data.players, user_id) and not is_map_key(data.spectators, user_id),
      do: {:keep_state, data, [{:reply, from, {:error, :not_in_lobby}}]}

  def handle_event({:call, from}, {:spectate, user_id}, _state, %LT.Data{} = data)
      when is_map_key(data.spectators, user_id) do
    if data.spectators[user_id].join_queue_position == nil do
      {:keep_state, data, [{:reply, from, :ok}]}
    else
      data = put_in(data.spectators[user_id].join_queue_position, nil)
      update = %{spectators: %{user_id => %{join_queue_position: nil}}}
      broadcast_update({:update, nil, update}, data)
      {:keep_state, data, [{:reply, from, :ok}]}
    end
  end

  def handle_event({:call, from}, {:spectate, user_id}, _state, %LT.Data{} = data)
      when is_map_key(data.players, user_id) do
    events = [%Events.MovePlayerToSpec{user_id: user_id, spec_data: %{join_queue_position: nil}}]
    data = process_events(data, events).data
    {:keep_state, data, [{:reply, from, :ok}]}
  end

  def handle_event({:call, from}, {:join_battle, user_id}, _state, %LT.Data{} = data)
      when not is_map_key(data.players, user_id) and not is_map_key(data.spectators, user_id),
      do: {:keep_state, data, [{:reply, from, {:error, :not_in_lobby}}]}

  def handle_event({:call, from}, {:join_battle, _user_id}, _state, %LT.Data{} = data)
      when is_nil(data.current_battle),
      do: {:keep_state, data, [{:reply, from, {:error, :invalid_battle}}]}

  def handle_event({:call, from}, {:join_battle, user_id}, _state, %LT.Data{} = data) do
    %{name: name, password: password} =
      get_in(data.spectators[user_id]) || get_in(data.players[user_id])

    # For simplicity sake, make it a synchronous call. This is not the greatest
    # solution since it implies a roundtrip to the autohost (through the battle
    # process) and will effectively block all other operations on the lobby
    # during that time. We can refactor that later to make it truly async
    # Also, we could cache this data against each player, but similarly, this
    # is a small optimisation. It's simpler to leave all battle membership decision
    # in the hand of the corresponding battle process.
    resp = TachyonBattle.add_player(data.current_battle.id, user_id, name, password)

    case resp do
      {:ok, %{ips: ips, port: port}} ->
        join_data = %{
          ips: ips,
          port: port,
          engine: %{version: data.engine_version},
          game: %{springName: data.game_version},
          map: %{springName: data.map_name}
        }

        Player.lobby_join_battle(
          user_id,
          {data.current_battle.id, data.current_battle.pid},
          join_data,
          password
        )

        {:keep_state, data, [{:reply, from, :ok}]}

      {:error, err} ->
        {:keep_state, data, [{:reply, from, {:error, err}}]}
    end
  end

  def handle_event(
        {:call, from},
        {:update_client_status, user_id, _update_data},
        _state,
        %LT.Data{} = data
      )
      when not is_map_key(data.players, user_id) and not is_map_key(data.spectators, user_id),
      do: {:keep_state, data, [{:reply, from, {:error, :not_in_lobby}}]}

  # maybe we'll want to keep track of client status when they move from player
  # to spec, but for now, just reject the request for non players.
  def handle_event(
        {:call, from},
        {:update_client_status, user_id, _update_data},
        _state,
        %LT.Data{} = data
      )
      when is_map_key(data.spectators, user_id),
      do: {:keep_state, data, [{:reply, from, {:error, :not_a_player}}]}

  def handle_event(
        {:call, from},
        {:update_client_status, user_id, update_data},
        _state,
        %LT.Data{} = data
      ) do
    supported_properties = [:ready?, :asset_status]

    event = %Events.UpdateClientStatus{
      user_id: user_id,
      client_status_updates: Map.take(update_data, supported_properties)
    }

    data = process_events(data, [event]).data
    {:keep_state, data, [{:reply, from, :ok}]}
  end

  def handle_event({:call, from}, {:add_bot, user_id, _add_data}, _state, %LT.Data{} = data)
      when not is_map_key(data.players, user_id) and not is_map_key(data.spectators, user_id),
      do: {:keep_state, data, [{:reply, from, {:error, :not_in_lobby}}]}

  def handle_event({:call, from}, {:add_bot, _user_id, add_data}, _state, %LT.Data{} = data)
      when add_data.ally_team >= length(data.ally_team_config) or add_data.ally_team < 0,
      do: {:keep_state, data, [{:reply, from, {:error, :invalid_ally_team}}]}

  def handle_event({:call, from}, {:add_bot, user_id, add_data}, _state, %LT.Data{} = data) do
    ally_team = add_data.ally_team
    ally_team_capacity = Enum.at(data.ally_team_config, ally_team).max_teams

    in_team_count = team_count(ally_team, data.players)

    if in_team_count >= ally_team_capacity do
      {:keep_state, data, [{:reply, from, {:error, :ally_team_full}}]}
    else
      bot_id = "bot-#{data.bot_idx_counter}"

      bot = %LT.Bot{
        id: bot_id,
        team: {ally_team, in_team_count, 0},
        host_user_id: user_id,
        short_name: add_data.short_name,
        name: add_data.name,
        version: add_data.version,
        options: add_data.options
      }

      data =
        put_in(data.players[bot.id], bot)
        |> Map.update!(:bot_idx_counter, &(&1 + 1))

      broadcast_update({:update, nil, %{players: %{bot.id => bot}}}, data)

      {:keep_state, data, [{:reply, from, {:ok, bot.id}}]}
    end
  end

  def handle_event({:call, from}, {:remove_bot, bot_id}, _state, %LT.Data{} = data)
      when not is_map_key(data.players, bot_id),
      do: {:keep_state, data, [{:reply, from, {:error, :invalid_bot_id}}]}

  def handle_event({:call, from}, {:remove_bot, bot_id}, _state, %LT.Data{} = data) do
    events = [
      %Events.RemovePlayerFromLobby{player_id: bot_id},
      %Events.RepackPlayers{},
      %Events.FillFromJoinQueue{}
    ]

    data = process_events(data, events).data

    {:keep_state, data, [{:reply, from, :ok}]}
  end

  def handle_event({:call, from}, {:update_bot, %{id: bot_id}}, _state, %LT.Data{} = data)
      when not is_map_key(data.players, bot_id),
      do: {:keep_state, data, [{:reply, from, {:error, :invalid_bot_id}}]}

  def handle_event(
        {:call, from},
        {:update_bot, %{id: bot_id} = update_data},
        _state,
        %LT.Data{} = data
      ) do
    data = update_in(data.players[bot_id], &Collections.patch_merge(&1, update_data))
    broadcast_update({:update, nil, %{players: %{bot_id => update_data}}}, data)
    {:keep_state, data, [{:reply, from, :ok}]}
  end

  def handle_event(
        {:call, from},
        {:update_properties, _user_id, data},
        _state,
        %LT.Data{} = fsm_data
      )
      when map_size(data) == 0,
      do: {:keep_state, fsm_data, [{:reply, from, :ok}]}

  def handle_event(
        {:call, from},
        {:update_properties, user_id, data},
        _state,
        %LT.Data{} = fsm_data
      ) do
    # for now, all properties can only be updated by bosses, so shortcut the reduce
    is_allowed? = not fsm_data.boss_enabled? or MapSet.member?(fsm_data.bosses, user_id)

    if is_allowed? do
      {events, errors} =
        Enum.reduce(data, {[], []}, fn {k, v}, {events, errors} ->
          case update_property(k, v, fsm_data, user_id) do
            {:error, msg} ->
              {events, [msg | errors]}

            {:ok, new_events} ->
              {events ++ new_events, errors}
          end
        end)

      if Enum.empty?(errors) do
        final_data = process_events(fsm_data, events).data
        {:keep_state, final_data, [{:reply, from, :ok}]}
      else
        message = Enum.join(errors, ", ")
        {:keep_state, fsm_data, [{:reply, from, {:error, "Cannot update lobby: #{message}"}}]}
      end
    else
      {:keep_state, fsm_data,
       [{:reply, from, {:error, "Cannot update lobby: you are not a boss"}}]}
    end
  end

  def handle_event(
        {:call, from},
        {:vote_submit, _user_id, {vote_id, _ballot}},
        _state,
        %LT.Data{} = data
      )
      when data.current_vote.id != vote_id,
      do: {:keep_state, data, [{:reply, from, {:error, :invalid_vote}}]}

  def handle_event(
        {:call, from},
        {:vote_submit, user_id, {_vote_id, ballot}},
        _state,
        %LT.Data{} = data
      ) do
    if is_map_key(data.current_vote.voters, user_id) do
      event = %Events.CastVote{user_id: user_id, vote: data.current_vote, ballot: ballot}
      data = process_events(data, [event]).data
      {:keep_state, data, [{:reply, from, :ok}]}
    else
      {:keep_state, data, [{:reply, from, {:error, :invalid_vote}}]}
    end
  end

  def handle_event(
        {:call, from},
        {:send_message, from_id, _msg_content},
        _state,
        %LT.Data{} = data
      )
      when not is_map_key(data.players, from_id) and not is_map_key(data.spectators, from_id),
      do: {:keep_state, data, [{:reply, from, {:error, :invalid_request, :not_in_lobby}}]}

  def handle_event(
        {:call, from},
        {:send_message, from_id, msg_content},
        _state,
        %LT.Data{} = data
      ) do
    msg =
      Messaging.new(
        msg_content,
        {:lobby, data.id, from_id},
        :erlang.monotonic_time(:micro_seconds)
      )

    Enum.concat(data.players, data.spectators)
    |> Enum.each(fn {id, _data} ->
      if id != from_id, do: Messaging.send(msg, {:player, id})
    end)

    {:keep_state, data, [{:reply, from, :ok}]}
  end

  def handle_event({:call, from}, {:join_queue, user_id}, _state, %LT.Data{} = data)
      when not is_map_key(data.players, user_id) and not is_map_key(data.spectators, user_id),
      do: {:keep_state, data, [{:reply, from, {:error, :not_in_lobby}}]}

  def handle_event({:call, from}, {:join_queue, user_id}, _state, %LT.Data{} = data) do
    cond do
      # already in the join queue, do nothing. This avoid someone
      # losing their position if they fat-finger the button
      get_in(data.spectators[user_id].join_queue_position) != nil ->
        {:keep_state, data, [{:reply, from, :ok}]}

      # there is no one in the join queue. So going into the join queue will immediately put
      # the player back into an ally team. Although they may end up in a different ally team
      # it is largely useless, so for simplicity sake, ignore the join_queue command
      is_map_key(data.players, user_id) and
          Enum.all?(data.spectators, fn {_id, s} -> s.join_queue_position == nil end) ->
        {:keep_state, data, [{:reply, from, :ok}]}

      # swap the player with the first in the join queue
      is_map_key(data.players, user_id) ->
        s_id = get_first_player_in_join_queue(data.spectators)
        player = data.players[user_id]
        pos = find_spec_queue_pos(data.spectators)

        events = [
          %Events.MoveSpecToPlayer{user_id: s_id, player_data: %{team: player.team}},
          %Events.MovePlayerToSpec{user_id: user_id, spec_data: %{join_queue_position: pos}}
        ]

        data = process_events(data, events).data

        {:keep_state, data, [{:reply, from, :ok}]}

      # spec getting into the join queue
      true ->
        data =
          case find_team(data.ally_team_config, data.players) do
            nil ->
              pos = find_spec_queue_pos(data.spectators)

              data =
                update_in(data.spectators[user_id], fn s ->
                  s |> Map.put(:join_queue_position, pos)
                end)

              update = %{spectators: %{user_id => %{join_queue_position: pos}}}
              broadcast_update({:update, nil, update}, data)

            team ->
              events = [
                %Events.MoveSpecToPlayer{user_id: user_id, player_data: %{team: team}}
              ]

              process_events(data, events).data
          end

        {:keep_state, data, [{:reply, from, :ok}]}
    end
  end

  def handle_event(
        {:call, from},
        {:kickban, user_id, _target_id, _ban_until},
        _state,
        %LT.Data{} = data
      )
      when not is_map_key(data.players, user_id) and not is_map_key(data.spectators, user_id),
      do: {:keep_state, data, [{:reply, from, {:error, :not_in_lobby}}]}

  def handle_event(
        {:call, from},
        {:kickban, _user_id, target_id, _ban_until},
        _state,
        %LT.Data{} = data
      )
      when not is_map_key(data.players, target_id) and not is_map_key(data.spectators, target_id),
      do: {:keep_state, data, [{:reply, from, {:error, :invalid_request}}]}

  def handle_event(
        {:call, from},
        {:kickban, user_id, target_id, ban_until},
        _state,
        %LT.Data{} = data
      ) do
    cond do
      not Enum.empty?(data.bosses) and not MapSet.member?(data.bosses, user_id) ->
        {:keep_state, data, [{:reply, from, {:error, :not_boss}}]}

      Enum.empty?(data.bosses) and Enum.count(data.players, &(!bot_id?(elem(&1, 0)))) > 1 ->
        vote = new_vote(data, user_id, {:kickban, target_id, ban_until})
        events = [%Events.StartVote{vote_state: vote}]
        data = process_events(data, events).data

        {:keep_state, data, [{:reply, from, :ok}]}

      true ->
        data =
          process_events(data, [%Events.Kickban{user_id: target_id, ban_until: ban_until}]).data

        {:keep_state, data, [{:reply, from, :ok}]}
    end
  end

  def handle_event(
        {:call, from},
        {:appoint_boss, user_id, _appointee_id},
        _state,
        %LT.Data{} = data
      )
      when not is_map_key(data.players, user_id) and not is_map_key(data.spectators, user_id),
      do: {:keep_state, data, [{:reply, from, {:error, :not_in_lobby}}]}

  def handle_event(
        {:call, from},
        {:appoint_boss, _user_id, appointee_id},
        _state,
        %LT.Data{} = data
      )
      when not is_map_key(data.players, appointee_id) and
             not is_map_key(data.spectators, appointee_id),
      do: {:keep_state, data, [{:reply, from, {:error, :not_in_lobby}}]}

  def handle_event(
        {:call, from},
        {:appoint_boss, user_id, appointee_id},
        _state,
        %LT.Data{} = data
      ) do
    cond do
      not data.boss_enabled? ->
        {:keep_state, data, [{:reply, from, {:error, :no_boss_allowed}}]}

      not Enum.empty?(data.bosses) and not MapSet.member?(data.bosses, user_id) ->
        {:keep_state, data, [{:reply, from, {:error, :not_a_boss}}]}

      Enum.empty?(data.bosses) and Enum.count(data.players, &(!bot_id?(elem(&1, 0)))) > 1 ->
        vote = new_vote(data, user_id, {:appoint_boss, appointee_id})
        events = [%Events.StartVote{vote_state: vote}]
        data = process_events(data, events).data
        {:keep_state, data, [{:reply, from, :ok}]}

      MapSet.member?(data.bosses, appointee_id) ->
        {:keep_state, data, [{:reply, from, :ok}]}

      true ->
        events = [%Events.UpdateBoss{action: :add, appointee_id: appointee_id}]
        data = process_events(data, events).data
        {:keep_state, data, [{:reply, from, :ok}]}
    end
  end

  def handle_event({:call, from}, {:unboss, user_id, _boss_id}, _state, %LT.Data{} = data)
      when not is_map_key(data.players, user_id) and not is_map_key(data.spectators, user_id),
      do: {:keep_state, data, [{:reply, from, {:error, :not_in_lobby}}]}

  def handle_event({:call, from}, {:unboss, _user_id, boss_id}, _state, %LT.Data{} = data)
      when not is_map_key(data.players, boss_id) and not is_map_key(data.spectators, boss_id),
      do: {:keep_state, data, [{:reply, from, {:error, :not_in_lobby}}]}

  def handle_event({:call, from}, {:unboss, user_id, boss_id}, _state, %LT.Data{} = data) do
    cond do
      not MapSet.member?(data.bosses, user_id) ->
        {:keep_state, data, [{:reply, from, {:error, :not_a_boss}}]}

      not MapSet.member?(data.bosses, boss_id) ->
        {:keep_state, data, [{:reply, from, :ok}]}

      true ->
        events = [%Events.UpdateBoss{action: :remove, appointee_id: boss_id}]
        data = process_events(data, events).data
        {:keep_state, data, [{:reply, from, :ok}]}
    end
  end

  def handle_event({:call, from}, {:start_battle, user_id}, _state, %LT.Data{} = data)
      when not is_map_key(data.players, user_id) and not is_map_key(data.spectators, user_id),
      do: {:keep_state, data, [{:reply, from, {:error, :not_in_lobby}}]}

  def handle_event({:call, from}, {:start_battle, _user_id}, _state, %LT.Data{} = data)
      when data.current_battle != nil,
      do: {:keep_state, data, [{:reply, from, {:error, :battle_already_started}}]}

  def handle_event({:call, from}, {:start_battle, _user_id}, _state, %LT.Data{} = data) do
    with autohost_id when autohost_id != nil <- Autohost.find_autohost(),
         {:ok, {battle_id, battle_pid} = battle_data, host_data} <-
           TachyonBattle.start_battle(
             autohost_id,
             gen_start_script(data),
             false
           ) do
      start_data = %{
        ips: host_data.ips,
        port: host_data.port,
        engine: %{version: data.engine_version},
        game: %{springName: data.game_version},
        map: %{springName: data.map_name}
      }

      for {p_id, p} <- Enum.concat(data.players, data.spectators),
          is_map_key(p, :password),
          do: Player.lobby_join_battle(p_id, battle_data, start_data, p.password)

      now = DateTime.utc_now()

      battle = %LT.CurrentBattle{id: battle_id, pid: battle_pid, started_at: now}

      data =
        %{data | current_battle: battle}
        |> Map.update!(:monitors, &MC.monitor(&1, battle_pid, :current_battle))
        |> Map.update!(:counter, &(&1 + 1))

      broadcast_update({:update, nil, %{current_battle: data.current_battle}}, data)
      update_list(data, %{current_battle: %{started_at: now}})

      {:keep_state, data, [{:reply, from, :ok}]}
    else
      nil ->
        Logger.warning("No autohost available to start lobby battle")
        {:keep_state, data, [{:reply, from, {:error, :no_autohost}}]}

      {:error, reason} ->
        Logger.error("Cannot start lobby battle: #{inspect(reason)}")
        {:keep_state, data, [{:reply, from, {:error, reason}}]}
    end
  end

  def handle_event({:call, from}, :get_start_script, _state, %LT.Data{} = data),
    do: {:keep_state, data, [{:reply, from, gen_start_script(data)}]}

  def handle_event({:call, from}, {:apply_events, events, opts}, _state, %LT.Data{} = data) do
    final_aggregate = process_events(data, events, opts)
    {:keep_state, final_aggregate.data, [{:reply, from, :ok} | final_aggregate.actions]}
  end

  def handle_event(:info, {:DOWN, ref, :process, _pid, :shutdown}, state, %LT.Data{} = data) do
    val = MC.get_val(data.monitors, ref)
    data = Map.update!(data, :monitors, &MC.demonitor_by_val(&1, val))

    case state do
      :shutting_down -> {:keep_state, data}
      _other -> {:next_state, :shutting_down, data}
    end
  end

  # only DOWN events matter when shutting down the lobby, everything else should be ignored
  def handle_event(:info, _msg, :shutting_down, %LT.Data{} = data) do
    {:keep_state, data}
  end

  def handle_event(:info, {:DOWN, ref, :process, _obj, reason}, _state, %LT.Data{} = data) do
    val = MC.get_val(data.monitors, ref)
    data = Map.update!(data, :monitors, &MC.demonitor_by_val(&1, val))

    case val do
      {:user, user_id} ->
        Logger.debug("user #{user_id} disappeared from the lobby because #{inspect(reason)}")

        aggregate =
          cond do
            is_map_key(data.players, user_id) ->
              remove_player_from_lobby(user_id, data)

            is_map_key(data.spectators, user_id) ->
              remove_spectator_from_lobby(user_id, data)
          end

        {:keep_state, aggregate.data, aggregate.actions}

      :current_battle ->
        data =
          Map.put(data, :current_battle, nil)
          |> Map.update!(:counter, &(&1 + 1))

        broadcast_update({:update, nil, %{current_battle: nil}}, data)
        update_list(data, %{current_battle: nil})
        {:keep_state, data}

      nil ->
        {:keep_state, data}
    end
  end

  def handle_event(:info, {:vote_timeout, vote_id}, _state, %LT.Data{} = data)
      when data.current_vote.id == vote_id do
    event = %Events.VoteEnded{
      finished_at: DateTime.utc_now(),
      vote: data.current_vote,
      outcome: :timeout
    }

    data = process_events(data, [event]).data
    {:keep_state, data}
  end

  def handle_event(:info, {:vote_timeout, _vote_id}, _state, %LT.Data{} = data),
    do: {:keep_state, data}

  def handle_event(:info, {:ban_expired, user_id}, _state, %LT.Data{} = data) do
    {:keep_state, update_in(data.banned_users, &Map.delete(&1, user_id))}
  end

  def handle_event(:info, {:EXIT, _pid, reason}, _state, %LT.Data{} = _data) do
    {:stop, reason}
  end

  def handle_event(:info, {:nodeup, new_node}, _state, %LT.Data{} = data) do
    Cluster.wait_teiserver_ready(new_node)

    if data.primary? do
      # TODO: handle the case where this fails. The most likely is when
      # the new node is the new primary, and it has already been started
      # through a lobby call
      :ok = :erpc.call(new_node, LobbySupervisor, :start_replica, [data])
    end

    data = %{data | primary?: routing_key(data.id) |> Cluster.primary?()}
    {:keep_state, data, []}
  end

  def handle_event(:info, {:nodedown, _old_node}, _state, %LT.Data{} = data) do
    data = %{data | primary?: routing_key(data.id) |> Cluster.primary?()}
    {:keep_state, data}
  end

  def handle_event(:internal, :empty, _state, %LT.Data{} = data) do
    Logger.info("Lobby shutting down because empty")
    {:stop, {:shutdown, :empty}, data}
  end

  def handle_event(:state_timeout, :snapshot_timeout, :starting_up, %LT.Data{} = data) do
    Logger.warning("failed to recover before time out. Missing #{inspect(data.ids_to_rejoin)}")
    message = %{event: :remove_lobby, lobby_id: data.id}
    PubSubHelper.broadcast(list_topic(), message)
    {:stop, :normal}
  end

  @impl :gen_statem
  def terminate(:shutdown, :shutting_down, data) do
    if Tachyon.should_restore_state?() do
      to_save =
        data
        |> Map.drop([:monitors])
        |> Map.update!(:players, fn ps ->
          for {k, v} <- ps, into: %{}, do: {k, Map.replace(v, :pid, nil)}
        end)
        |> Map.update!(:spectators, fn ps ->
          for {k, v} <- ps, into: %{}, do: {k, Map.replace(v, :pid, nil)}
        end)
        |> :erlang.term_to_binary()

      KvStore.put("lobby", data.id, to_save)
    end
  end

  def terminate(_reason, _state, _data), do: nil

  @spec via_tuple(LT.Types.id()) :: GenServer.name()
  defp via_tuple(lobby_id) do
    LobbyRegistry.via_tuple(lobby_id)
  end

  defp call_lobby(lobby_id, message, opts \\ []) do
    timeout = Keyword.get(opts, :timeout, @default_call_timeout)
    {m, f, a} = {:gen_statem, :call, [via_tuple(lobby_id), message, timeout]}

    if Keyword.get(opts, :to_primary?, true) do
      routing_key(lobby_id) |> Cluster.primary_apply({m, f, a}, timeout)
    else
      apply(m, f, a)
    end
  catch
    :exit, {:noproc, _reason} -> {:error, :invalid_lobby}
    :exit, {:shutdown, _reason} -> {:error, :invalid_lobby}
  end

  def routing_key(id), do: {:lobby, id}

  @spec get_overview_from_state(state :: LT.Data.t()) :: LT.ListOverview.t()
  defp get_overview_from_state(%LT.Data{} = state) do
    %LT.ListOverview{
      counter: state.counter,
      name: state.name,
      player_count: map_size(state.players),
      max_player_count:
        Enum.sum(
          for at <- state.ally_team_config, team <- at.teams do
            team.max_players
          end
        ),
      map_name: state.map_name,
      engine_version: state.engine_version,
      game_version: state.game_version,
      boss_enabled?: state.boss_enabled?,
      current_battle: nil,
      tags: state.tags
    }
  end

  @spec get_details_from_state(LT.Data.t()) :: LT.Details.t()
  defp get_details_from_state(%LT.Data{} = state) do
    {players, bots} = Enum.split_with(state.players, fn {_id, p} -> is_map_key(p, :pid) end)

    players =
      Enum.map(players, fn {p_id, %LT.Player{} = p} ->
        player = %LT.PlayerDetails{
          id: p.id,
          team: p.team,
          ready?: p.ready?,
          asset_status: p.asset_status
        }

        {p_id, player}
      end)
      |> Enum.into(%{})

    spectators =
      Enum.map(state.spectators, fn {s_id, %LT.Spectator{} = s} ->
        spec = %LT.SpectatorDetails{id: s_id, join_queue_position: s.join_queue_position}
        {s_id, spec}
      end)
      |> Enum.into(%{})

    vote_history =
      Enum.map(state.vote_history, fn {id, %LT.VoteRecord{} = record} ->
        details = %LT.VoteDetails{
          finished_at: record.finished_at,
          vote: record.vote.action,
          outcome: record.outcome
        }

        {id, details}
      end)
      |> Enum.into(%{})

    %LT.Details{
      id: state.id,
      name: state.name,
      map_name: state.map_name,
      game_version: state.game_version,
      engine_version: state.engine_version,
      boss_enabled?: state.boss_enabled?,
      bosses: state.bosses,
      ally_team_config: state.ally_team_config,
      game_options: state.game_options,
      tags: state.tags,
      players: players,
      bots: Map.new(bots),
      spectators: spectators,
      current_battle: state.current_battle,
      current_vote: state.current_vote,
      vote_history: vote_history
    }
  end

  defp register_new_lobby(state) do
    overview = get_overview_from_state(state)
    ListMonitor.register(state.id, self())
    LobbyRegistry.put_overview(state.id, overview)

    message = %{
      event: :add_lobby,
      counter: state.counter,
      lobby_id: state.id,
      overview: overview
    }

    if routing_key(state.id) |> Cluster.primary?() do
      PubSubHelper.broadcast(list_topic(), message)
    end
  end

  defp process_events(%LT.Data{} = data, events, opts \\ []) do
    {primary, replicas} = routing_key(data.id) |> Cluster.split_nodes()

    primary? = Node.self() == primary
    final_aggregate = compute_aggregate(data, events)

    if primary? do
      sender_id = opts[:sender_id]

      if final_aggregate.changes != %{},
        do: broadcast_update({:update, sender_id, final_aggregate.changes}, final_aggregate.data)

      replicate_events(replicas, data, events, opts)
    end

    broadcast_list_updates(final_aggregate)

    # some events have an impact on the state, like vote timeout for example
    # this isn't ideal since each event need to make a decision whether it
    # should also apply on the replicas, but for now™ it'll do
    Enum.each(
      final_aggregate.side_effects,
      &process_event_action(&1, primary?, final_aggregate.data)
    )

    final_aggregate
  end

  def compute_aggregate(%LT.Data{} = data, events) do
    aggregate = %LT.Aggregate{data: data}

    final_aggregate = Enum.reduce(events, aggregate, &Event.apply_event/2)

    initial_player_count = Enum.count(data.players, fn {_id, p} -> not bot_id?(p.id) end)

    final_player_count =
      Enum.count(final_aggregate.data.players, fn {_id, p} -> not bot_id?(p.id) end)

    final_aggregate =
      update_in(final_aggregate, [Access.key!(:overview_changes)], fn changes ->
        if final_player_count != initial_player_count do
          Map.put(changes, :player_count, final_player_count)
        else
          changes
        end
      end)
      |> update_in([Access.key!(:data), Access.key!(:counter)], fn c ->
        if final_aggregate.data != data,
          do: c + 1,
          else: c
      end)

    lobby_empty? =
      map_size(final_aggregate.data.players) == 0 and
        map_size(final_aggregate.data.spectators) == 0

    if lobby_empty? do
      %{final_aggregate | actions: final_aggregate.actions ++ [{:next_event, :internal, :empty}]}
    else
      final_aggregate
    end
  end

  defp broadcast_list_updates(%LT.Aggregate{} = agg)
       when map_size(agg.data.players) == 0 and map_size(agg.data.spectators) == 0,
       do: :ok

  defp broadcast_list_updates(%LT.Aggregate{} = agg) when agg.overview_changes == %{}, do: :ok

  defp broadcast_list_updates(%LT.Aggregate{} = aggregate) do
    message = %{
      counter: aggregate.data.counter,
      event: :update_lobby,
      lobby_id: aggregate.data.id,
      changes: aggregate.overview_changes
    }

    LobbyRegistry.put_overview(aggregate.data.id, get_overview_from_state(aggregate.data))

    if routing_key(aggregate.data.id) |> Cluster.primary?() do
      PubSubHelper.broadcast(list_topic(), message)
    end

    :ok
  end

  # find an empty slot for a player/bot to play
  # this function isn't too efficient, but it's never going to be run on
  # massive inputs since the engine cannot support more than 254 players anyway
  @spec find_team([LT.AllyTeamConfig.t()], %{LT.Types.player_id() => LT.Player.t() | LT.Bot.t()}) ::
          LT.Types.team() | nil
  def find_team(ally_team_config, players) do
    # find the least full ally team
    ally_team =
      for {%LT.AllyTeamConfig{} = at, at_idx} <- Enum.with_index(ally_team_config) do
        total_capacity = Enum.sum_by(at.teams, fn t -> t.max_players end)

        capacity = total_capacity - team_count(at_idx, players)
        {capacity, at_idx, at.teams}
      end
      |> Enum.filter(fn {c, _idx, _teams} -> c > 0 end)
      # select the biggest capacity with the lowest index
      |> Enum.min(
        fn {c1, idx1, _teams1}, {c2, idx2, _teams2} ->
          c1 >= c2 && idx1 <= idx2
        end,
        fn -> nil end
      )

    case ally_team do
      nil ->
        nil

      {_capacity, at_idx, teams} ->
        {_capacity, t_idx, p_idx} =
          for {t, t_idx} <- Enum.with_index(teams) do
            player_count =
              Enum.count(players, fn {_id, %{team: {x, y, _player}}} ->
                x == at_idx && y == t_idx
              end)

            capacity = t.max_players - player_count
            {capacity, t_idx, player_count}
          end
          |> Enum.filter(fn {c, _idx, _count} -> c > 0 end)
          # guarantee not to raise an exception
          |> Enum.min()

        {at_idx, t_idx, p_idx}
    end
  end

  # return the number of players + bots in the given ally team
  defp team_count(ally_team, players) do
    Enum.count(players, fn {_id, %{team: {at, _team, _player}}} -> at == ally_team end)
  end

  defp broadcast_update({:update, user_id, updates}, state) do
    # internally bots and humans are in the same `players` group. But when
    # sending these updates for client consumption, they want players and bots
    # as separate.
    updates =
      if is_map_key(updates, :players) do
        {players, rest} = Map.pop!(updates, :players)
        {bots, players} = Enum.split_with(players, &bot_id?(elem(&1, 0)))

        %{players: Map.new(players), bots: Map.new(bots)}
        |> Enum.filter(&(elem(&1, 1) != %{}))
        |> Map.new()
        |> Map.merge(rest)
      else
        updates
      end

    broadcast_to_members(state, user_id, {:lobby, state.id, {:updated, updates}})
  end

  defp broadcast_to_members(state, sender_id, message) do
    for {p_id, p} <- state.players, p_id != sender_id, is_map_key(p, :pid) do
      send(p.pid, message)
    end

    for {s_id, s} <- state.spectators, s_id != sender_id do
      send(s.pid, message)
    end

    state
  end

  # what's the next index to use for join queue spec?
  defp find_spec_queue_pos(spectators) do
    max =
      Enum.reduce(spectators, nil, fn {_id, %LT.Spectator{} = s}, max_so_far ->
        cond do
          s.join_queue_position == nil -> max_so_far
          max_so_far == nil -> s.join_queue_position
          true -> max(max_so_far, s.join_queue_position)
        end
      end)

    (max || 0) + 1
  end

  # which player is next in the join queue?
  def get_first_player_in_join_queue(spectators) do
    Enum.reduce(spectators, {nil, nil}, fn {id, %LT.Spectator{} = s},
                                           {min_so_far, _prev_id} = acc ->
      cond do
        s.join_queue_position == nil ->
          acc

        min_so_far == nil || s.join_queue_position < min_so_far ->
          {s.join_queue_position, id}

        true ->
          acc
      end
    end)
    |> elem(1)
  end

  @spec remove_player_from_lobby(User.id(), LT.Data.t()) :: LT.Aggregate.t()
  defp remove_player_from_lobby(user_id, %LT.Data{} = data) do
    process_events(data, [%Events.RemovePlayerFromLobby{player_id: user_id}])
  end

  @spec remove_spectator_from_lobby(User.id(), LT.Data.t()) :: LT.Aggregate.t()
  defp remove_spectator_from_lobby(user_id, %LT.Data{} = data) do
    process_events(data, [%Events.RemoveSpecFromLobby{user_id: user_id}])
  end

  defp gen_password, do: :crypto.strong_rand_bytes(16) |> Base.encode16()

  defp ban_expired?(ban_until) do
    DateTime.compare(ban_until, DateTime.utc_now()) != :gt
  end

  # in tests, some user ids are string
  def bot_id?(id) when is_integer(id), do: false
  def bot_id?(id), do: String.starts_with?(id, "bot")

  @spec gen_start_script(LT.Data.t()) :: AT.StartScript.t()
  defp gen_start_script(%LT.Data{} = state) do
    sorted =
      Map.values(state.players)
      |> Enum.sort_by(& &1.team)
      |> Enum.group_by(&elem(&1.team, 0))
      |> Map.values()

    ally_teams =
      for {at, %LT.AllyTeamConfig{} = at_config} <- Enum.zip(sorted, state.ally_team_config) do
        teams =
          Enum.group_by(at, &elem(&1.team, 1))
          |> Map.values()

        teams =
          for team <- teams do
            {players, bots} = Enum.split_with(team, fn p -> is_map_key(p, :pid) end)

            players =
              for player <- players do
                %AT.Player{
                  user_id: player.id,
                  name: player.name,
                  password: player.password
                }
              end

            bots =
              for %LT.Bot{} = bot <- bots do
                %AT.Bot{
                  host_user_id: bot.host_user_id,
                  name: Map.get(bot, :name),
                  ai_short_name: bot.short_name,
                  ai_version: Map.get(bot, :version),
                  ai_options: bot.options
                }
              end

            %{players: players, bots: bots}
            |> Enum.reject(fn {_key, v} -> v |> Enum.empty?() end)
            |> Map.new()
          end

        %{teams: teams, startBox: at_config.start_box}
      end

    %AT.StartScript{
      engine_version: state.engine_version,
      game_name: state.game_version,
      map_name: state.map_name,
      start_pos_type: :ingame,
      ally_teams: ally_teams,
      spectators:
        Enum.map(state.spectators, fn {_s_id, s} ->
          %{user_id: s.id, name: s.name, password: s.password}
        end),
      game_options: state.game_options
    }
  end

  @spec update_property(atom(), term(), LT.Data.t(), User.id()) ::
          {:ok, [term()]} | {:error, String.t()}
  defp update_property(:name, new_name, _state, _user_id) do
    # we can expand lobby name validation later with LobbyRestrictions
    case LobbyLib.validate_name(new_name) do
      {:error, error} ->
        {:error, error}

      :ok ->
        {:ok, [%Events.UpdateLobbyName{new_name: new_name}]}
    end
  end

  defp update_property(:map_name, new_map, %LT.Data{} = state, user_id) do
    cond do
      not is_map_key(state.players, user_id) ->
        {:error, "Only players can change the map"}

      state.current_vote ->
        case state.current_vote.action do
          # make changing map idempotent, it's just a nicer API this way
          {:change_map, ^new_map} -> {:ok, []}
          _other_action -> {:error, :vote_in_progress}
        end

      Enum.count(state.players, fn {_id, p} -> not bot_id?(p.id) end) > 1 ->
        vote = new_vote(state, user_id, {:change_map, new_map})
        {:ok, [%Events.StartVote{vote_state: vote}]}

      true ->
        {:ok, [%Events.UpdateMapName{new_map: new_map}]}
    end
  end

  defp update_property(:ally_team_config, new_config, state, _user_id) do
    {:ok,
     [%Events.UpdateAllyTeamConfig{old_config: state.ally_team_config, new_config: new_config}]}
  end

  defp update_property(:game_options, changes, _state, _user_id) do
    # TODO: set a size limit on that thing to avoid a DOS
    {:ok, [%Events.UpdateGameOptions{changes: changes}]}
  end

  defp update_property(:tags, changes, _state, _user_id) do
    {:ok, [%Events.UpdateTags{changes: changes}]}
  end

  defp update_property(prop, _value, _state, _user_id),
    do: {:error, "update #{prop} is not supported"}

  defp process_event_action({:vote_ended, vote, outcome}, primary?, fsm_data) do
    if primary? do
      broadcast_to_members(fsm_data, nil, {:lobby, fsm_data.id, {:vote_ended, vote.id, outcome}})
    end
  end

  defp process_event_action({:send_after, time, message}, _primary?, _fsm_data) do
    :timer.send_after(time, message)
  end

  defp process_event_action({:send_to_user, pid, message}, primary?, _fsm_data) do
    if primary?, do: send(pid, message)
  end

  # create a default vote object
  defp new_vote(state, initiator_id, action) do
    vote_duration_s = 60

    voters =
      for {_id, p} <- state.players, !bot_id?(p.id), into: %{} do
        if p.id == initiator_id, do: {p.id, :yes}, else: {p.id, :pending}
      end

    # ensure we need absolute majority.
    # 0.501 works until 254 players, which is the hard limit of players
    # in a game
    quorum = (map_size(voters) * 0.501) |> :math.ceil() |> trunc()

    %LT.VoteState{
      id: "vote-#{state.vote_idx}",
      action: action,
      initiator: initiator_id,
      voters: voters,
      duration_s: vote_duration_s,
      until: DateTime.utc_now() |> DateTime.shift(Duration.new!(second: vote_duration_s)),
      quorum: quorum,
      majority: quorum
    }
  end

  defp update_list(%LT.Data{} = data, changes) do
    message = %{
      event: :update_lobby,
      counter: data.counter,
      lobby_id: data.id,
      changes: changes
    }

    PubSubHelper.broadcast(list_topic(), message)
  end

  defp replicate_events(replicas, %LT.Data{} = data, events, opts) do
    mfa = {__MODULE__, :apply_events, [data.id, events, opts]}

    # TODO: handle the case where the lobby doesn't exist on the replica
    # or if the replica fails to apply the events somehow
    # Also need to figure out the thorny case where the replica is
    # starting up and bootstraping its state.
    Cluster.multi_apply(replicas, mfa)
    |> Enum.each(fn {node, result} ->
      if result != :ok, do: raise("Error on node #{node}: #{inspect(result)}")
    end)

    :ok
  end
end
