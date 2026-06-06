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
  # translate the operation into an event. See `@typep event` for the list.
  # These events are then reduced/folded into an aggregate. This aggregate
  # is used to
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
  alias Teiserver.Autohost
  alias Teiserver.Data.Types, as: T
  alias Teiserver.Helpers.Collections
  alias Teiserver.Helpers.MonitorCollection, as: MC
  alias Teiserver.KvStore
  alias Teiserver.Lobby.LobbyLib
  alias Teiserver.Messaging
  alias Teiserver.Player
  alias Teiserver.Tachyon
  alias Teiserver.TachyonBattle
  alias Teiserver.TachyonLobby
  # lobby types
  alias Teiserver.TachyonLobby.Types, as: LT

  require Logger

  @behaviour :gen_statem

  @type asset_status :: :missing | :downloading | :complete

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

  # the list of internal events used to manipulate the lobby data, but also
  # for updates to broadcast to members
  # for more info on specific events, check how they are handled by `process_event/2`
  @typep event ::
           {:move_player, LT.Types.player_id(), LT.Types.team()}
           | {:add_spectator, LT.Spectator.t()}
           | {:remove_player_from_lobby, LT.Types.player_id()}
           | {:remove_spec_from_lobby, T.userid()}
           | {:move_spec_to_player, T.userid(), player_data :: map()}
           | {:move_player_to_spec, T.userid(), spec_data :: map()}
           | :repack_players
           | :fill_from_join_queue
           | {:update_client_status, T.userid(), client_status :: map()}
           | {:update_lobby_name, new_name :: String.t()}
           | {:update_map_name, new_name :: String.t()}
           | {:update_ally_team_config, old_config :: [LT.AllyTeamConfig.t()],
              new_config :: [LT.AllyTeamConfig.t()]}
           | {:update_game_options, changes :: %{String.t() => String.t() | nil}}
           | {:update_tags, changes :: %{String.t() => map() | nil}}
           | {:start_vote, LT.VoteState.t()}
           | {:cast_vote, T.userid(), LT.VoteState.vote_ballot()}
           | {:vote_ended, DateTime.t(), LT.VoteState.vote_outcome()}
           | {:update_boss, :add | :remove, T.userid()}

  @spec gen_id() :: LT.Types.id()
  def gen_id, do: UUID.uuid4()

  @default_call_timeout 5000
  @max_vote_history_size 10

  # note: this uses a pid and not a lobby id because it's (currently) only
  # used by the lobby list process to bootstrap its state, and at that time
  # it has the pid (from the registry).
  # but if the needs arise, this could be overloaded to use a lobby id
  # and the usual via_tuple mechanism
  @spec get_overview(pid()) :: LT.ListOverview.t() | nil
  def get_overview(lobby_pid) do
    :gen_statem.call(lobby_pid, :get_overview, @default_call_timeout)
  catch
    :exit, {:noproc, _details} -> nil
  end

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

  @spec join(LT.Types.id(), LT.PlayerJoinData.t(), pid()) ::
          {:ok, lobby_pid :: pid(), LT.Details.t()} | {:error, reason :: term()}
  def join(lobby_id, %LT.PlayerJoinData{} = join_data, pid \\ self()) do
    call_lobby(lobby_id, {:join, join_data, pid})
  end

  @spec leave(LT.Types.id(), T.userid()) :: :ok | {:error, reason :: :lobby_full | term()}
  def leave(lobby_id, user_id) do
    via_tuple(lobby_id) |> :gen_statem.call({:leave, user_id}, @default_call_timeout)
  catch
    :exit, {:noproc, _details} -> {:error, :invalid_lobby}
    # lobby shutting down would result in the player leaving anyway
    :exit, {:shutdown, _reason} -> :ok
  end

  @spec join_ally_team(LT.Types.id(), T.userid(), allyTeam :: non_neg_integer()) ::
          {:ok, LT.Details.t()}
          | {:error,
             reason :: :invalid_lobby | :not_in_lobby | :invalid_ally_team | :ally_team_full}
  def join_ally_team(lobby_id, user_id, ally_team) do
    call_lobby(lobby_id, {:join_ally_team, user_id, ally_team})
  end

  @spec spectate(LT.Types.id(), T.userid()) :: :ok | {:error, :invalid_lobby | :not_in_lobby}
  def spectate(lobby_id, user_id) do
    call_lobby(lobby_id, {:spectate, user_id})
  end

  @doc """
  request to be added as a spectator to the battle being played
  """
  @spec join_battle(LT.Types.id(), T.userid()) ::
          :ok | {:error, :invalid_lobby | :not_in_lobby | :invalid_battle | term()}
  def join_battle(lobby_id, user_id) do
    call_lobby(lobby_id, {:join_battle, user_id})
  end

  @spec rejoin(LT.Types.id(), T.userid(), pid()) ::
          {:ok, lobby_pid :: pid(), LT.Details.t()} | {:error, :invalid_lobby}
  def rejoin(lobby_id, user_id, pid) do
    call_lobby(lobby_id, {:rejoin, user_id, pid})
  end

  @type client_status_update_data :: %{
          optional(:ready?) => boolean(),
          optional(:asset_status) => asset_status()
        }
  @spec update_client_status(LT.Types.id(), T.userid(), client_status_update_data()) ::
          :ok | {:error, :invalid_lobby | :not_in_lobby | :not_a_player}
  def update_client_status(lobby_id, user_id, update_data) do
    call_lobby(lobby_id, {:update_client_status, user_id, update_data})
  end

  @type add_bot_opt ::
          {:name, String.t()} | {:version, String.t()} | {:options, %{String.t() => String.t()}}
  @type add_bot_opts :: [add_bot_opt]

  @spec add_bot(
          LT.Types.id(),
          T.userid(),
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
  @spec update_properties(LT.Types.id(), T.userid(), lobby_update_data()) ::
          :ok | {:error, :invalid_lobby | term()}
  def update_properties(lobby_id, user_id, update_data) do
    call_lobby(lobby_id, {:update_properties, user_id, update_data})
  end

  @spec vote_submit(LT.Types.id(), T.userid(), {String.t(), LT.VoteState.vote_ballot()}) ::
          :ok | {:error, :invalid_lobby | :invalid_vote}
  def vote_submit(lobby_id, user_id, ballot) do
    call_lobby(lobby_id, {:vote_submit, user_id, ballot})
  end

  @spec send_message(LT.Types.id(), T.userid(), String.t()) ::
          :ok | {:error, :invalid_request, reason :: term()}
  def send_message(lobby_id, from_id, msg_content) do
    call_lobby(lobby_id, {:send_message, from_id, msg_content})
  end

  @doc """
  This should only be used for tests, because there is some gnarly logic in
  generating the start script and it's a bit hard to test end to end
  """
  @spec get_start_script(LT.Types.id()) :: Autohost.start_script()
  def get_start_script(lobby_id) do
    via_tuple(lobby_id) |> :gen_statem.call(:get_start_script, @default_call_timeout)
  end

  @spec join_queue(LT.Types.id(), T.userid()) :: :ok | {:error, :invalid_lobby | :not_in_lobby}
  def join_queue(lobby_id, user_id) do
    call_lobby(lobby_id, {:join_queue, user_id})
  end

  @spec appoint_boss(LT.Types.id(), T.userid(), appointee_id :: T.userid()) ::
          :ok | {:error, :invalid_lobby | :not_in_lobby | :no_boss_allowed | :not_a_boss}
  def appoint_boss(lobby_id, user_id, appointee_id) do
    call_lobby(lobby_id, {:appoint_boss, user_id, appointee_id})
  end

  @spec unboss(LT.Types.id(), T.userid(), boss_id :: T.userid()) ::
          :ok | {:error, :invalid_lobby | :not_in_lobby | :no_boss_allowed | :not_a_boss}
  def unboss(lobby_id, user_id, boss_id) do
    call_lobby(lobby_id, {:unboss, user_id, boss_id})
  end

  @spec start_battle(LT.Types.id(), T.userid()) ::
          :ok | {:error, reason :: :not_in_lobby | :battle_already_started | term()}
  def start_battle(lobby_id, user_id) do
    call_lobby(lobby_id, {:start_battle, user_id})
  end

  @doc """
  used only for testing
  """
  def trigger_vote_timeout(lobby_id, vote_id) do
    TachyonLobby.Registry.lookup(lobby_id) |> send({:vote_timeout, vote_id})
  end

  @impl :gen_statem
  def callback_mode, do: :handle_event_function

  @impl :gen_statem
  @spec init({LT.Types.id(), {:user, LT.StartParams.t()} | {:snapshot, binary()}}) ::
          {:ok, term(), LT.Data.t()}
  def init({id, {:user, %LT.StartParams{} = start_params}}) do
    Process.flag(:trap_exit, true)
    Logger.metadata(actor_type: :lobby, actor_id: id)

    monitors =
      MC.new() |> MC.monitor(start_params.creator_pid, {:user, start_params.creator_data.id})

    bosses =
      if start_params.boss_enabled?,
        do: MapSet.new([start_params.creator_data.id]),
        else: MapSet.new()

    state =
      %LT.Data{
        id: id,
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

    TachyonLobby.List.register_lobby(self(), id, get_overview_from_state(state))
    Logger.info("Lobby created by user #{start_params.creator_data.id}")
    {:ok, :running, state}
  end

  def init({id, {:snapshot, serialized_data}}) do
    Process.flag(:trap_exit, true)
    Logger.metadata(actor_type: :lobby, actor_id: id)
    Logger.debug("Restoring lobby from snapshot")

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

    timeout = Tachyon.get_restoration_timeout()
    actions = [{:state_timeout, timeout, :snapshot_timeout}]

    {:ok, :starting_up, data, actions}
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
        TachyonLobby.List.register_lobby(self(), data.id, get_overview_from_state(data))

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

    events = [{:add_spectator, spec_data}]
    data = process_events(events, data) |> broadcast_updates(user_id) |> Map.get(:data)
    {:keep_state, data, [{:reply, from, {:ok, self(), get_details_from_state(data)}}]}
  end

  def handle_event({:call, from}, {:leave, user_id}, _state, %LT.Data{} = data)
      when is_map_key(data.players, user_id) do
    case remove_player_from_lobby(user_id, data) do
      data when map_size(data.players) > 0 or map_size(data.spectators) > 0 ->
        {:keep_state, data, [{:reply, from, :ok}]}

      data ->
        {:keep_state, data, [{:reply, from, :ok}, {:next_event, :internal, :empty}]}
    end
  end

  def handle_event({:call, from}, {:leave, user_id}, _state, %LT.Data{} = data)
      when is_map_key(data.spectators, user_id) do
    data = remove_spectator_from_lobby(user_id, data)

    if map_size(data.players) > 0 or map_size(data.spectators) > 0 do
      {:keep_state, data, [{:reply, from, :ok}]}
    else
      {:keep_state, data, [{:reply, from, :ok}, {:next_event, :internal, :empty}]}
    end
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
            events = [{:move_player, user_id, team}, :repack_players]
            data = process_events(events, data) |> broadcast_updates() |> Map.get(:data)

            {:keep_state, data, [{:reply, from, {:ok, get_details_from_state(data)}}]}

          {false, _s} ->
            # Adding a spec into an ally team. The way we construct the team
            # means it doesn't require any reshuffling of existing players
            events = [{:move_spec_to_player, user_id, %{team: team}}]
            aggregate = process_events(events, data) |> broadcast_updates()
            process_event_actions(aggregate)
            data = aggregate.data

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
    events = [
      {:move_player_to_spec, user_id, %{join_queue_position: nil}},
      :repack_players,
      :fill_from_join_queue
    ]

    aggregate = process_events(events, data) |> broadcast_updates()
    process_event_actions(aggregate)

    {:keep_state, aggregate.data, [{:reply, from, :ok}]}
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
    event = {:update_client_status, user_id, Map.take(update_data, supported_properties)}
    data = process_events([event], data) |> broadcast_updates() |> Map.get(:data)
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
    events = [{:remove_player_from_lobby, bot_id}, :repack_players, :fill_from_join_queue]
    aggregate = process_events(events, data) |> broadcast_updates()
    process_event_actions(aggregate)

    {:keep_state, aggregate.data, [{:reply, from, :ok}]}
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
    patch_merge(data.players[bot_id], update_data)
    data = update_in(data.players[bot_id], &patch_merge(&1, update_data))
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
        final_data = process_events(events, fsm_data) |> broadcast_updates() |> Map.get(:data)
        # broadcast_list_updates(events, fsm_data, final_data)
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
      event = {:cast_vote, user_id, ballot}
      aggregate = process_events([event], data) |> broadcast_updates()
      process_event_actions(aggregate)
      {:keep_state, aggregate.data, [{:reply, from, :ok}]}
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
          {:move_spec_to_player, s_id, %{team: player.team}},
          {:move_player_to_spec, user_id, %{join_queue_position: pos}}
        ]

        data = process_events(events, data) |> broadcast_updates() |> Map.get(:data)

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
              events = [{:move_spec_to_player, user_id, %{team: team}}]
              process_events(events, data) |> broadcast_updates() |> Map.get(:data)
          end

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

        :timer.seconds(vote.duration_s)
        |> :timer.send_after({:vote_timeout, vote.id})

        events = [{:start_vote, vote}]
        data = process_events(events, data) |> broadcast_updates() |> Map.get(:data)
        {:keep_state, data, [{:reply, from, :ok}]}

      true ->
        events = [{:update_boss, :add, appointee_id}]
        data = process_events(events, data) |> broadcast_updates() |> Map.get(:data)
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
        events = [{:update_boss, :remove, boss_id}]
        data = process_events(events, data) |> broadcast_updates() |> Map.get(:data)
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

      broadcast_update({:update, nil, %{current_battle: data.current_battle}}, data)
      TachyonLobby.List.update_lobby(data.id, %{current_battle: %{started_at: now}})

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

    data =
      case val do
        {:user, user_id} ->
          Logger.debug("user #{user_id} disappeared from the lobby because #{inspect(reason)}")

          cond do
            is_map_key(data.players, user_id) ->
              remove_player_from_lobby(user_id, data)

            is_map_key(data.spectators, user_id) ->
              remove_spectator_from_lobby(user_id, data)
          end

        :current_battle ->
          data = Map.put(data, :current_battle, nil)
          broadcast_update({:update, nil, %{current_battle: nil}}, data)
          TachyonLobby.List.update_lobby(data.id, %{current_battle: nil})
          data

        nil ->
          data
      end

    if Enum.empty?(data.players) and Enum.empty?(data.spectators) do
      {:keep_state, data, [{:next_event, :internal, :empty}]}
    else
      {:keep_state, data}
    end
  end

  def handle_event(:info, {:vote_timeout, vote_id}, _state, %LT.Data{} = data)
      when data.current_vote.id == vote_id do
    event = {:vote_ended, DateTime.utc_now(), :timeout}
    aggregate = process_events([event], data) |> broadcast_updates()
    process_event_actions(aggregate)
    {:keep_state, aggregate.data}
  end

  def handle_event(:info, {:vote_timeout, _vote_id}, _state, %LT.Data{} = data),
    do: {:keep_state, data}

  def handle_event(:info, {:EXIT, _pid, reason}, _state, %LT.Data{} = _data) do
    {:stop, reason}
  end

  def handle_event(:internal, :empty, _state, %LT.Data{} = data) do
    Logger.info("Lobby shutting down because empty")
    {:stop, {:shutdown, :empty}, data}
  end

  def handle_event(:state_timeout, :snapshot_timeout, :starting_up, %LT.Data{} = data) do
    Logger.warning("failed to recover before time out. Missing #{inspect(data.ids_to_rejoin)}")
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
    TachyonLobby.Registry.via_tuple(lobby_id)
  end

  defp call_lobby(lobby_id, message, timeout \\ @default_call_timeout) do
    via_tuple(lobby_id) |> :gen_statem.call(message, timeout)
  catch
    :exit, {:noproc, _reason} -> {:error, :invalid_lobby}
    :exit, {:shutdown, _reason} -> {:error, :invalid_lobby}
  end

  @spec get_overview_from_state(state :: LT.Data.t()) :: LT.ListOverview.t()
  defp get_overview_from_state(%LT.Data{} = state) do
    %LT.ListOverview{
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

  # Given a list of events to process (in the event sourcing way) and the initial
  # state to apply these events to, returns the final state alongside any
  # potential update events that should also be broadcasted to members
  @typep aggregate :: %{
           initial_data: LT.Data.t(),
           data: LT.Data.t(),
           updates: [event()],
           actions: [event_actions()]
         }
  @typep event_actions :: {:vote_ended, final_vote :: LT.VoteState.t(), outcome :: term()}
  @spec process_events([event()], LT.Data.t()) :: aggregate()
  defp process_events(events, %LT.Data{} = state),
    do:
      Enum.reduce(
        events,
        %{initial_data: state, data: state, updates: [], actions: []},
        &process_event/2
      )

  @spec process_event(event(), %{data: LT.Data.t(), updates: [event()]}) :: %{
          data: LT.Data.t(),
          updates: [event()]
        }
  defp process_event({:move_player, p_id, team} = ev, aggregate) do
    aggregate
    |> update_in([:data, Access.key!(:players), p_id], fn p ->
      Map.merge(p, %{team: team, ready?: false, asset_status: :complete})
    end)
    |> update_in([:updates], &[ev | &1])
  end

  defp process_event({:add_spectator, spec_data} = ev, aggregate) do
    aggregate
    |> put_in([:data, Access.key!(:spectators), spec_data.id], spec_data)
    |> update_in(
      [:data, Access.key!(:monitors)],
      &MC.monitor(&1, spec_data.pid, {:user, spec_data.id})
    )
    |> update_in([:updates], &[ev | &1])
  end

  defp process_event({:remove_player_from_lobby, p_id} = ev, aggregate) do
    aggregate =
      aggregate
      |> update_in([:data, Access.key!(:players)], &Map.delete(&1, p_id))
      |> update_in([:data, Access.key!(:monitors)], &MC.demonitor_by_val(&1, {:user, p_id}))
      |> update_in([:updates], &[ev | &1])

    aggregate = process_event({:cast_vote, p_id, :abstain}, aggregate)
    process_event({:update_boss, :remove, p_id}, aggregate)
  end

  defp process_event({:remove_spec_from_lobby, s_id} = ev, aggregate) do
    aggregate =
      aggregate
      |> update_in([:data, Access.key!(:spectators)], &Map.delete(&1, s_id))
      |> update_in([:data, Access.key!(:monitors)], &MC.demonitor_by_val(&1, {:user, s_id}))
      |> update_in([:updates], &[ev | &1])

    aggregate = process_event({:cast_vote, s_id, :abstain}, aggregate)
    process_event({:update_boss, :remove, s_id}, aggregate)
  end

  defp process_event({:move_spec_to_player, p_id, %{team: team}} = ev, aggregate) do
    spec_data = aggregate.data.spectators[p_id]

    player = %LT.Player{
      id: spec_data.id,
      name: spec_data.name,
      password: spec_data.password,
      pid: spec_data.pid,
      team: team,
      ready?: false,
      asset_status: :complete
    }

    aggregate
    |> update_in([:data, Access.key!(:spectators)], &Map.delete(&1, p_id))
    |> put_in([:data, Access.key!(:players), p_id], player)
    |> update_in([:updates], &[ev | &1])
  end

  defp process_event({:move_player_to_spec, p_id, spec_data} = ev, aggregate) do
    %LT.Player{} = player = aggregate.data.players[p_id]

    spec = %LT.Spectator{
      id: player.id,
      name: player.name,
      password: player.password,
      pid: player.pid,
      join_queue_position: spec_data.join_queue_position
    }

    aggregate
    |> update_in([:data, Access.key!(:players)], &Map.delete(&1, p_id))
    |> put_in([:data, Access.key!(:spectators), p_id], spec)
    |> update_in([:updates], &[ev | &1])
  end

  # given a state where the players may not be all on consecutive ally team and
  # teams, re-assign all required player.team so that they are all consecutive
  # player should never change ally team when doing so, only teams
  # and since archon isn't really supported, this ends up only repacking the teams
  defp process_event(:repack_players, aggregate) do
    data = aggregate.data

    repacked_players =
      for {%LT.AllyTeamConfig{} = _at, at_idx} <- Enum.with_index(data.ally_team_config) do
        Enum.filter(data.players, fn {_id, %{team: {p_at, _team, _player}}} -> at_idx == p_at end)
        |> Enum.map(fn {_id, p} -> p end)
        |> Enum.sort_by(& &1.team)
        |> Enum.with_index()
        |> Enum.map(fn {p, idx} -> {p.id, Map.update!(p, :team, &put_elem(&1, 1, idx))} end)
      end
      |> List.flatten()
      |> Enum.into(%{})

    events =
      Enum.map(repacked_players, fn {p_id, p} ->
        if data.players[p_id].team != p.team do
          {:move_player, p_id, p.team}
        end
      end)
      |> Enum.reject(&is_nil/1)

    aggregate
    |> put_in([:data, Access.key!(:players)], repacked_players)
    |> update_in([:updates], &(events ++ &1))
  end

  defp process_event(:fill_from_join_queue, aggregate) do
    case add_player_from_join_queue(aggregate.data) do
      nil ->
        aggregate

      ev ->
        new_aggregate = process_event(ev, aggregate)
        process_event(:fill_from_join_queue, new_aggregate)
    end
  end

  defp process_event({:update_client_status, p_id, changes} = ev, aggregate) do
    aggregate
    |> update_in([:data, Access.key!(:players), p_id], &Map.merge(&1, changes))
    |> update_in([:updates], &[ev | &1])
  end

  defp process_event({:update_lobby_name, new_name} = ev, aggregate) do
    aggregate
    |> put_in([:data, Access.key!(:name)], new_name)
    |> update_in([:updates], &[ev | &1])
  end

  defp process_event({:update_map_name, new_name} = ev, aggregate) do
    aggregate
    |> put_in([:data, Access.key!(:map_name)], new_name)
    |> update_in([:updates], &[ev | &1])
  end

  defp process_event({:update_ally_team_config, _old_config, new_config} = ev, aggregate) do
    state = aggregate.data

    spec_ids =
      Enum.map(state.players, fn {p_id, %{team: {x, y, z}}} ->
        with at_config = %LT.AllyTeamConfig{} when not is_nil(at_config) <- Enum.at(new_config, x),
             team_config when not is_nil(team_config) <- Enum.at(at_config.teams, y) do
          if y < at_config.max_teams && z < team_config.max_players,
            do: nil,
            else: p_id
        else
          nil -> p_id
        end
      end)
      |> Enum.reject(&is_nil/1)

    {bot_ids, player_ids} = Enum.split_with(spec_ids, &bot_id?/1)

    position_offset =
      case get_first_player_in_join_queue(state.spectators) do
        nil -> 0
        spec_id -> state.spectators[spec_id].join_queue_position - Enum.count(player_ids) - 1
      end

    spec_events =
      Enum.with_index(player_ids, position_offset)
      |> Enum.map(fn {p_id, pos} -> {:move_player_to_spec, p_id, %{join_queue_position: pos}} end)

    bot_events = Enum.map(bot_ids, fn b_id -> {:remove_player_from_lobby, b_id} end)

    events = spec_events ++ bot_events ++ [:repack_players, :fill_from_join_queue]

    new_aggregate = process_events(events, Map.replace!(state, :ally_team_config, new_config))

    # We put players in join queue, and then fill the teams with
    # the join queue, which means we can have events like
    # :move_player_to_spec and later :move_spec_to_player
    # which would generate an update with %{spectators: %{x => nil}}
    # where x was never a spectator to beging with.
    # So we need to detect these events and replace the pair with a :move_player
    # event instead.
    added_ids =
      Enum.map(new_aggregate.updates, fn
        {:move_spec_to_player, id, _data} -> id
        _other -> nil
      end)
      |> Enum.reject(&is_nil/1)

    ids_to_fix = player_ids |> MapSet.new() |> MapSet.intersection(MapSet.new(added_ids))

    final_events =
      Enum.map(new_aggregate.updates, fn ev ->
        case ev do
          {:move_player_to_spec, x, _spec_data} ->
            if MapSet.member?(ids_to_fix, x),
              do: nil,
              else: ev

          {:move_spec_to_player, x, data} ->
            if MapSet.member?(ids_to_fix, x),
              do: {:move_player, x, data.team},
              else: ev

          _other ->
            ev
        end
      end)
      |> Enum.reject(&is_nil/1)

    new_aggregate |> put_in([:updates], [ev | final_events] ++ aggregate.updates)
  end

  defp process_event({:update_game_options, changes} = ev, aggregate) do
    aggregate
    |> update_in([:data, Access.key!(:game_options)], &patch_merge(&1, changes))
    |> Map.update!(:updates, &[ev | &1])
  end

  defp process_event({:update_tags, changes} = ev, aggregate) do
    aggregate
    |> update_in([:data, Access.key!(:tags)], &patch_merge(&1, changes))
    |> Map.update!(:updates, &[ev | &1])
  end

  defp process_event({:start_vote, %LT.VoteState{} = vote_state} = ev, aggregate) do
    aggregate
    |> put_in([:data, Access.key!(:current_vote)], vote_state)
    |> update_in([:data, Access.key!(:vote_idx)], &(&1 + 1))
    |> Map.update!(:updates, &[ev | &1])
  end

  defp process_event({:cast_vote, user_id, _ballot}, aggregate)
       when is_nil(aggregate.data.current_vote) or
              not is_map_key(aggregate.data.current_vote.voters, user_id),
       do: aggregate

  defp process_event({:cast_vote, user_id, ballot} = ev, aggregate) do
    new_aggregate =
      aggregate
      |> put_in([:data, Access.key!(:current_vote), Access.key!(:voters), user_id], ballot)

    case vote_result(new_aggregate.data.current_vote) do
      :undecided ->
        Map.update!(new_aggregate, :updates, &[ev | &1])

      {:ended, result} ->
        vote = new_aggregate.data.current_vote
        new_aggregate = process_event({:vote_ended, DateTime.utc_now(), result}, new_aggregate)

        case {result, vote.action} do
          {:failed, _action} ->
            new_aggregate

          {:passed, {:change_map, new_map}} ->
            process_event({:update_map_name, new_map}, new_aggregate)

          {:passed, {:appoint_boss, boss_id}} ->
            process_event({:update_boss, :add, boss_id}, new_aggregate)
            # just let the thing crash if a new vote action shows up. It'll be easy
            # to spot and fix/add support. :start isn't yet supported
        end
    end
  end

  # don't bother cancelling the vote timeout timer. The event handler checks the vote id
  # and it allows us not to worry about storing the tref
  defp process_event({:vote_ended, ts, outcome}, aggregate) do
    vote_ev = {:vote_ended, aggregate.data.current_vote, outcome}

    vote_record = %LT.VoteRecord{
      vote: aggregate.data.current_vote,
      finished_at: ts,
      outcome: outcome
    }

    history = Map.put(aggregate.data.vote_history, aggregate.data.current_vote.id, vote_record)

    history =
      if map_size(history) > @max_vote_history_size do
        dates =
          Enum.map(history, fn {_id, record} -> record.finished_at end)
          |> Enum.sort()

        cutoff = Enum.at(dates, 4)

        Enum.filter(history, fn {_id, record} -> record.finished_at >= cutoff end)
        |> Enum.into(%{})
      else
        history
      end

    aggregate
    |> put_in([:data, Access.key!(:current_vote)], nil)
    |> put_in([:data, Access.key!(:vote_history)], history)
    |> Map.update!(:updates, &[{:vote_ended, vote_record} | &1])
    |> Map.update!(:actions, &[vote_ev | &1])
  end

  defp process_event({:update_boss, :add, appointee_id} = ev, aggregate) do
    if MapSet.member?(aggregate.data.bosses, appointee_id) do
      aggregate
    else
      aggregate
      |> update_in([:data, Access.key!(:bosses)], &MapSet.put(&1, appointee_id))
      |> Map.update!(:updates, &[ev | &1])
    end
  end

  defp process_event({:update_boss, :remove, boss_id} = ev, aggregate) do
    if MapSet.member?(aggregate.data.bosses, boss_id) do
      aggregate
      |> update_in([:data, Access.key!(:bosses)], &MapSet.delete(&1, boss_id))
      |> Map.update!(:updates, &[ev | &1])
    else
      aggregate
    end
  end

  # avoid sending a useless lobby list update when the last member of the lobby
  # just left. The caller of this function will detect the lobby is empty and
  # terminate the process, which will trigger the final lobby list update for
  # this lobby
  @spec broadcast_updates(aggregate()) :: aggregate()
  defp broadcast_updates(%{data: data} = aggregate)
       when map_size(data.players) == 0 and map_size(data.spectators) == 0,
       do: aggregate

  defp broadcast_updates(aggregate, sender_id \\ nil) do
    change_map = Enum.reduce(aggregate.updates, %{}, &update_change_from_event/2)

    if change_map != %{} do
      broadcast_update({:update, sender_id, change_map}, aggregate.data)
      broadcast_list_updates(aggregate)
    end

    aggregate
  end

  defp update_change_from_event({:move_player, p_id, team}, change_map) do
    change_map
    |> Map.put_new(:players, %{})
    |> Map.update!(:players, fn players ->
      players
      |> Map.put_new(p_id, %{})
      |> update_in([p_id], fn p ->
        Map.merge(%{team: team, ready?: false, asset_status: :complete}, p)
      end)
    end)
  end

  defp update_change_from_event({:add_spectator, spec_data}, change_map) do
    change_map
    |> Map.put_new(:spectators, %{})
    |> put_in([:spectators, spec_data.id], Map.take(spec_data, [:join_queue_position]))
  end

  defp update_change_from_event({:remove_player_from_lobby, p_id}, change_map) do
    change_map
    |> Map.put_new(:players, %{})
    |> put_in([:players, p_id], nil)
  end

  defp update_change_from_event({:remove_spec_from_lobby, s_id}, change_map) do
    change_map
    |> Map.put_new(:spectators, %{})
    |> put_in([:spectators, s_id], nil)
  end

  defp update_change_from_event({:move_spec_to_player, p_id, player_data}, change_map) do
    player_data = Map.merge(%{ready?: false, asset_status: :complete}, player_data)

    change_map
    |> Map.put_new(:players, %{})
    |> put_in([:players, p_id], player_data)
    |> Map.put_new(:spectators, %{})
    |> put_in([:spectators, p_id], nil)
  end

  defp update_change_from_event({:move_player_to_spec, p_id, spec_data}, change_map) do
    change_map
    |> Map.put_new(:players, %{})
    |> put_in([:players, p_id], nil)
    |> Map.put_new(:spectators, %{})
    |> put_in([:spectators, p_id], spec_data)
  end

  defp update_change_from_event(:repack_players, change_map), do: change_map

  defp update_change_from_event({:update_client_status, p_id, changes}, change_map) do
    change_map
    |> Map.put_new(:players, %{})
    |> put_in([:players, p_id], changes)
  end

  defp update_change_from_event({:update_lobby_name, new_name}, change_map),
    do: Map.put(change_map, :name, new_name)

  defp update_change_from_event({:update_map_name, new_name}, change_map),
    do: Map.put(change_map, :map_name, new_name)

  defp update_change_from_event({:update_ally_team_config, old_config, new_config}, change_map) do
    changes =
      Collections.zip_with_padding(old_config, new_config, nil)
      |> Enum.map(fn
        {_old_at, nil} ->
          nil

        {nil, new_at} ->
          new_at

        {%LT.AllyTeamConfig{} = old_at, %LT.AllyTeamConfig{} = new_at} ->
          # we are broadcasting patch updates, so structs are meaningless
          # in this context
          new_at = Map.from_struct(new_at)

          Map.update!(new_at, :teams, fn new_teams ->
            Collections.zip_with_padding(old_at.teams, new_teams, nil)
            |> Enum.map(fn {_old_team, new_team} -> new_team end)
          end)
      end)

    Map.put(change_map, :ally_team_config, changes)
  end

  defp update_change_from_event({:update_game_options, changes}, change_map),
    do: Map.put(change_map, :game_options, changes)

  defp update_change_from_event({:update_tags, changes}, change_map),
    do: Map.put(change_map, :tags, changes)

  defp update_change_from_event({:start_vote, vote}, change_map),
    do: Map.put(change_map, :current_vote, vote)

  defp update_change_from_event({:cast_vote, user_id, ballot}, change_map) do
    change_map
    |> Map.put_new(:current_vote, %{})
    |> Map.update!(:current_vote, &Map.put_new(&1, :voters, %{}))
    |> put_in([:current_vote, :voters, user_id], ballot)
  end

  defp update_change_from_event({:vote_ended, record}, change_map) do
    change_map
    |> Map.put(:current_vote, nil)
    |> Map.put_new(:vote_history, %{})
    |> put_in([:vote_history, record.vote.id], %{
      vote: record.vote.action,
      finished_at: record.finished_at,
      outcome: record.outcome
    })
  end

  defp update_change_from_event({:update_boss, :add, appointee_id}, change_map) do
    change_map
    |> Map.put_new(:bosses, %{})
    |> put_in([:bosses, appointee_id], %{})
  end

  defp update_change_from_event({:update_boss, :remove, boss_id}, change_map) do
    change_map
    |> Map.put_new(:bosses, %{})
    |> put_in([:bosses, boss_id], nil)
  end

  defp broadcast_list_updates(%{data: final_state})
       when map_size(final_state.players) == 0 and map_size(final_state.spectators) == 0,
       do: final_state

  # events, starting_state, final_state) do
  defp broadcast_list_updates(%{updates: events, data: data} = aggregate) do
    initial_player_count =
      Enum.count(aggregate.initial_data.players, fn {_id, p} -> not bot_id?(p.id) end)

    final_player_count = Enum.count(aggregate.data.players, fn {_id, p} -> not bot_id?(p.id) end)

    change_map =
      Enum.reduce(events, %{}, fn ev, change_map ->
        case ev do
          {:update_lobby_name, new_name} ->
            Map.put(change_map, :name, new_name)

          {:update_map_name, new_name} ->
            Map.put(change_map, :map_name, new_name)

          {:update_ally_team_config, _old_config, new_config} ->
            change_map
            |> Map.put(
              :max_player_count,
              Enum.sum(
                for at <- new_config, team <- at.teams do
                  team.max_players
                end
              )
            )
            # although the player count may not have changed, for simplicity sake
            # just include it. We're already sending a message anyway
            |> Map.put(:player_count, final_player_count)

          _other ->
            change_map
        end
      end)

    change_map =
      if final_player_count != initial_player_count do
        Map.put(change_map, :player_count, final_player_count)
      else
        change_map
      end

    if change_map != %{}, do: TachyonLobby.List.update_lobby(data.id, change_map)
    aggregate
  end

  # find an empty slot for a player/bot to play
  # this function isn't too efficient, but it's never going to be run on
  # massive inputs since the engine cannot support more than 254 players anyway
  @spec find_team([LT.AllyTeamConfig.t()], %{LT.Types.player_id() => LT.Player.t() | LT.Bot.t()}) ::
          LT.Types.team() | nil
  defp find_team(ally_team_config, players) do
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
  defp get_first_player_in_join_queue(spectators) do
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

  @spec remove_player_from_lobby(T.userid(), LT.Data.t()) :: LT.Data.t()
  defp remove_player_from_lobby(user_id, %LT.Data{} = state) do
    # if the user leaving is associated with any bot, we need to remove all of
    # them as well.
    bot_ids_to_remove =
      Enum.filter(state.players, fn {_bot_id, b} -> Map.get(b, :host_user_id) == user_id end)
      |> Enum.map(&elem(&1, 0))

    events =
      Enum.map([user_id | bot_ids_to_remove], fn id -> {:remove_player_from_lobby, id} end) ++
        [
          :repack_players,
          :fill_from_join_queue
        ]

    aggregate = process_events(events, state) |> broadcast_updates()
    process_event_actions(aggregate)
    aggregate.data
  end

  @spec remove_spectator_from_lobby(T.userid(), LT.Data.t()) :: LT.Data.t()
  defp remove_spectator_from_lobby(user_id, %LT.Data{} = state) do
    bot_ids_to_remove =
      Enum.filter(state.players, fn {_bot_id, b} -> Map.get(b, :host_user_id) == user_id end)
      |> Enum.map(&elem(&1, 0))

    events =
      Enum.map(bot_ids_to_remove, fn id -> {:remove_player_from_lobby, id} end) ++
        [{:remove_spec_from_lobby, user_id}, :repack_players, :fill_from_join_queue]

    aggregate = process_events(events, state) |> broadcast_updates()
    process_event_actions(aggregate)
    aggregate.data
  end

  # Add the first player from the join queue to the player list and returns the
  # updated state alongside the player id that was added
  @spec add_player_from_join_queue(LT.Data.t()) :: event() | nil
  defp add_player_from_join_queue(%LT.Data{} = state) do
    player_to_add =
      case get_first_player_in_join_queue(state.spectators) do
        nil ->
          nil

        id ->
          case find_team(state.ally_team_config, state.players) do
            nil ->
              nil

            team ->
              {id, %{team: team, ready?: false, asset_status: :complete}}
          end
      end

    case player_to_add do
      nil ->
        nil

      {id, player_data} ->
        {:move_spec_to_player, id, player_data}
    end
  end

  defp gen_password, do: :crypto.strong_rand_bytes(16) |> Base.encode16()

  # in tests, some user ids are string
  defp bot_id?(id) when is_integer(id), do: false
  defp bot_id?(id), do: String.starts_with?(id, "bot")

  @spec gen_start_script(LT.Data.t()) :: Autohost.start_script()
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
                %{
                  user_id: player.id,
                  name: player.name,
                  password: player.password
                }
              end

            bots =
              for %LT.Bot{} = bot <- bots do
                %{
                  host_user_id: bot.host_user_id,
                  name: Map.get(bot, :name),
                  ai_short_name: bot.short_name,
                  ai_version: Map.get(bot, :version),
                  ai_options: bot.options
                }
                |> Enum.reject(fn {_key, v} -> v == nil || v == %{} end)
                |> Map.new()
              end

            %{players: players, bots: bots}
            |> Enum.reject(fn {_key, v} -> v |> Enum.empty?() end)
            |> Map.new()
          end

        %{teams: teams, startBox: at_config.start_box}
      end

    %{
      engine_version: state.engine_version,
      game_name: state.game_version,
      map_name: state.map_name,
      start_pos_type: :ingame,
      ally_teams: ally_teams,
      spectators:
        Enum.map(state.spectators, fn {_s_id, s} ->
          %{user_id: s.id, name: s.name, password: s.password}
        end)
    }
    |> Map.merge(Map.take(state, [:game_options]))
  end

  @spec update_property(atom(), term(), LT.Data.t(), T.userid()) ::
          {:ok, [event()]} | {:error, String.t()}
  defp update_property(:name, new_name, _state, _user_id) do
    # we can expand lobby name validation later with LobbyRestrictions
    case LobbyLib.validate_name(new_name) do
      {:error, error} ->
        {:error, error}

      :ok ->
        {:ok, [{:update_lobby_name, new_name}]}
    end
  end

  defp update_property(:map_name, new_name, %LT.Data{} = state, user_id) do
    cond do
      not is_map_key(state.players, user_id) ->
        {:error, "Only players can change the map"}

      state.current_vote ->
        case state.current_vote.action do
          # make changing map idempotent, it's just a nicer API this way
          {:change_map, ^new_name} -> {:ok, []}
          _other_action -> {:error, :vote_in_progress}
        end

      Enum.count(state.players, fn {_id, p} -> not bot_id?(p.id) end) > 1 ->
        vote = new_vote(state, user_id, {:change_map, new_name})

        :timer.seconds(vote.duration_s)
        |> :timer.send_after({:vote_timeout, vote.id})

        {:ok, [{:start_vote, vote}]}

      true ->
        {:ok, [{:update_map_name, new_name}]}
    end
  end

  defp update_property(:ally_team_config, new_config, state, _user_id) do
    {:ok, [{:update_ally_team_config, state.ally_team_config, new_config}]}
  end

  defp update_property(:game_options, changes, _state, _user_id) do
    # TODO: set a size limit on that thing to avoid a DOS
    {:ok, [{:update_game_options, changes}]}
  end

  defp update_property(:tags, changes, _state, _user_id) do
    {:ok, [{:update_tags, changes}]}
  end

  defp update_property(prop, _value, _state, _user_id),
    do: {:error, "update #{prop} is not supported"}

  defp process_event_actions(aggregate),
    do: Enum.each(aggregate.actions, &process_event_action(&1, aggregate.data))

  defp process_event_action({:vote_ended, vote, outcome}, fsm_data) do
    broadcast_to_members(fsm_data, nil, {:lobby, fsm_data.id, {:vote_ended, vote.id, outcome}})
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

  @spec vote_result(LT.VoteState.t()) :: :undecided | {:ended, :passed | :failed}
  defp vote_result(%LT.VoteState{} = vote) do
    votes = for {_user_id, v} <- vote.voters, do: v

    cond do
      Enum.count(votes, &(&1 != :pending)) < vote.quorum -> :undecided
      Enum.count(votes, &(&1 == :yes)) >= vote.majority -> {:ended, :passed}
      true -> {:ended, :failed}
    end
  end

  @doc """
  apply some updates onto a base map according to json merge patch semantics

  This function could be extracted out in a more general module but for now
  that'll do.
  """
  @spec patch_merge(base :: map(), updates :: map()) :: map()
  def patch_merge(base, updates) do
    Enum.reduce(updates, base, fn {k, v}, m ->
      cond do
        v == nil -> Map.delete(m, k)
        is_map(v) -> Map.update(m, k, v, &patch_merge(&1, v))
        true -> Map.put(m, k, v)
      end
    end)
  end
end
