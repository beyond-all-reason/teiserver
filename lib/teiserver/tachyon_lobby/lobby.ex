defmodule Teiserver.TachyonLobby.Lobby do
  @moduledoc """
  Represent a single lobby
  """

  require Logger

  @behaviour :gen_statem

  alias Teiserver.Asset
  alias Teiserver.Autohost
  alias Teiserver.Data.Types, as: T
  alias Teiserver.Helpers.MonitorCollection, as: MC
  alias Teiserver.Player
  alias Teiserver.Tachyon
  alias Teiserver.TachyonBattle
  alias Teiserver.TachyonLobby

  @type id :: String.t()

  @type ally_team_config :: [
          %{
            max_teams: pos_integer(),
            start_box: Asset.startbox(),
            teams: [
              %{
                max_players: pos_integer()
              }
            ]
          }
        ]

  @typedoc """
  Data required for a player to join a lobby. This allow lobbies to
  be agnostic of how players are represented in the system
  """
  @type player_join_data :: %{
          id: T.userid(),
          name: String.t()
        }

  @typedoc """
  the parameters required to create a new lobby.
  It's enough data to generate the initial lobby internal state, which in
  turn can be used to start a battle
  """
  @type start_params :: %{
          required(:creator_data) => player_join_data(),
          required(:creator_pid) => pid(),
          required(:name) => String.t(),
          required(:map_name) => String.t(),
          required(:ally_team_config) => ally_team_config(),
          optional(:game_version) => String.t(),
          optional(:engine_version) => String.t()
        }

  @typedoc """
  These represent the indices respectively into
  {ally team index, team index, player index}
  since we don't really support "archon mode" though, the player index
  is likely always going to be 0.
  For example, a player in the first ally team, in the second spot
  would have: {0, 1, 0}
  """
  @type team ::
          {allyTeam :: non_neg_integer(), team :: non_neg_integer(), player :: non_neg_integer()}

  @type asset_status :: :missing | :downloading | :ready

  @typedoc """
  The public state of the lobby. Anything that clients need to know about
  when in a lobby should be exposed in the details object
  """
  @type details :: %{
          id: id(),
          name: String.t(),
          map_name: String.t(),
          game_version: String.t(),
          engine_version: String.t(),
          ally_team_config: ally_team_config(),
          players: %{
            T.userid() => %{team: team(), ready?: boolean(), asset_status: asset_status()}
          },
          spectators: %{
            join_queue_position: number() | nil
          },
          bots: %{
            String.t() => %{
              host_user_id: T.userid(),
              team: team(),
              name: String.t(),
              short_name: String.t() | nil,
              version: String.t() | nil,
              options: %{String.t() => String.t()}
            }
          },
          current_battle:
            nil
            | %{
                id: Teiserver.TachyonBattle.id(),
                started_at: DateTime.t()
              }
        }

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

  # represent the ID of a user or a bot slated to play in the game (no spec)
  @typep player_id :: T.userid() | String.t()

  @typep player :: %{
           id: T.userid(),
           name: String.t(),
           # used to generate the start script, and then will be sent to the
           # player so they can join the battle
           password: String.t(),
           pid: pid(),
           team: team(),
           ready?: boolean(),
           asset_status: asset_status()
         }

  @typep spectator :: %{
           id: T.userid(),
           name: String.t(),
           # used to generate the start script, and then will be sent to the
           # player so they can join the battle
           password: String.t(),
           pid: pid(),
           join_queue_position: number() | nil
         }

  @typep bot :: %{
           id: String.t(),
           team: team(),
           host_user_id: T.userid(),
           short_name: String.t(),
           name: String.t() | nil,
           version: String.t() | nil,
           options: %{String.t() => String.t()}
         }

  @typep state :: %{
           id: id(),
           monitors: MC.t(),
           name: String.t(),
           map_name: String.t(),
           game_version: String.t(),
           engine_version: String.t(),
           ally_team_config: ally_team_config(),
           # used to track the players in the lobby.
           players: %{player_id() => player() | bot()},
           spectators: %{T.userid() => spectator()},
           bot_idx_counter: non_neg_integer(),
           current_battle:
             nil
             | %{
                 id: Teiserver.TachyonBattle.id(),
                 started_at: DateTime.t()
               },
           ids_to_rejoin: MapSet.t(T.userid())
         }

  # the list of internal events used to manipulate the lobby data, but also
  # for updates to broadcast to members
  # for more info on specific events, check how they are handled by `process_event/2`
  @typep event ::
           {:move_player, player_id(), team()}
           | {:remove_player_from_lobby, player_id()}
           | {:remove_spec_from_lobby, T.userid()}
           | {:move_spec_to_player, T.userid(), player_data :: map()}
           | {:move_player_to_spec, T.userid(), spec_data :: map()}
           | :repack_players
           | :fill_from_join_queue
           | {:update_client_status, T.userid(), client_status :: map()}
           | {:update_lobby_name, new_name :: String.t()}
           | {:update_map_name, new_name :: String.t()}
           | {:update_ally_team_config, old_config :: ally_team_config(),
              new_config :: ally_team_config()}

  @spec gen_id() :: id()
  def gen_id(), do: UUID.uuid4()

  @default_call_timeout 5000

  # note: this uses a pid and not a lobby id because it's (currently) only
  # used by the lobby list process to bootstrap its state, and at that time
  # it has the pid (from the registry).
  # but if the needs arise, this could be overloaded to use a lobby id
  # and the usual via_tuple mechanism
  @spec get_overview(pid()) :: TachyonLobby.List.overview() | nil
  def get_overview(lobby_pid) do
    :gen_statem.call(lobby_pid, :get_overview, @default_call_timeout)
  catch
    :exit, {:noproc, _} -> nil
  end

  @spec get_details(id()) :: {:ok, details()} | {:error, reason :: term()}
  def get_details(id) do
    :gen_statem.call(via_tuple(id), :get_details, @default_call_timeout)
  catch
    :exit, {:noproc, _} -> {:error, :invalid_lobby}
  end

  def child_spec({lobby_id, _} = args) do
    %{
      id: via_tuple(lobby_id),
      start: {__MODULE__, :start_link, [args]},
      restart: :temporary
    }
  end

  @spec start_link({id(), start_params()}) :: GenServer.on_start()
  def start_link({id, _start_params} = args) do
    :gen_statem.start_link(via_tuple(id), __MODULE__, args, [])
  end

  @spec join(id(), player_join_data(), pid()) ::
          {:ok, lobby_pid :: pid(), details()} | {:error, reason :: term()}
  def join(lobby_id, join_data, pid \\ self()) do
    :gen_statem.call(via_tuple(lobby_id), {:join, join_data, pid}, @default_call_timeout)
  catch
    :exit, {:noproc, _} -> {:error, :invalid_lobby}
  end

  @spec leave(id(), T.userid()) :: :ok | {:error, reason :: :lobby_full | term()}
  def leave(lobby_id, user_id) do
    :gen_statem.call(via_tuple(lobby_id), {:leave, user_id}, @default_call_timeout)
  catch
    :exit, {:noproc, _} -> {:error, :invalid_lobby}
  end

  @spec join_ally_team(id(), T.userid(), allyTeam :: non_neg_integer()) ::
          {:ok, details()}
          | {:error,
             reason :: :invalid_lobby | :not_in_lobby | :invalid_ally_team | :ally_team_full}
  def join_ally_team(lobby_id, user_id, ally_team) do
    :gen_statem.call(
      via_tuple(lobby_id),
      {:join_ally_team, user_id, ally_team},
      @default_call_timeout
    )
  catch
    :exit, {:noproc, _} -> {:error, :invalid_lobby}
  end

  @spec spectate(id(), T.userid()) :: :ok | {:error, :invalid_lobby | :not_in_lobby}
  def spectate(lobby_id, user_id) do
    :gen_statem.call(via_tuple(lobby_id), {:spectate, user_id}, @default_call_timeout)
  catch
    :exit, {:noproc, _} -> {:error, :invalid_lobby}
  end

  @spec rejoin(id(), T.userid(), pid()) ::
          {:ok, lobby_pid :: pid(), details()} | {:error, :invalid_lobby}
  def rejoin(lobby_id, user_id, pid) do
    :gen_statem.call(via_tuple(lobby_id), {:rejoin, user_id, pid}, @default_call_timeout)
  catch
    :exit, {:noproc, _} -> {:error, :invalid_lobby}
  end

  @type client_status_update_data :: %{
          optional(:ready?) => boolean(),
          optional(:asset_status) => asset_status()
        }
  @spec update_client_status(id(), T.userid(), client_status_update_data()) ::
          :ok | {:error, :invalid_lobby | :not_in_lobby | :not_a_player}
  def update_client_status(lobby_id, user_id, update_data) do
    :gen_statem.call(via_tuple(lobby_id), {:update_client_status, user_id, update_data})
  catch
    :exit, {:noproc, _} -> {:error, :invalid_lobby}
  end

  @type add_bot_opt ::
          {:name, String.t()} | {:version, String.t()} | {:options, %{String.t() => String.t()}}
  @type add_bot_opts :: [add_bot_opt]

  @spec add_bot(
          id(),
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
    :gen_statem.call(
      via_tuple(lobby_id),
      {:add_bot, user_id,
       %{
         ally_team: ally_team,
         short_name: short_name,
         name: opts[:name],
         version: opts[:version],
         options: Keyword.get(opts, :options, %{})
       }},
      @default_call_timeout
    )
  catch
    :exit, {:noproc, _} -> {:error, :invalid_lobby}
  end

  @spec remove_bot(id(), bot_id :: String.t()) :: :ok | {:error, :invalid_bot_id | term()}
  def remove_bot(lobby_id, bot_id) do
    :gen_statem.call(via_tuple(lobby_id), {:remove_bot, bot_id}, @default_call_timeout)
  catch
    :exit, {:noproc, _} -> {:error, :invalid_lobby}
  end

  @spec update_bot(id(), bot_update_data()) :: :ok | {:error, reason :: :invalid_bot_id | term()}
  def update_bot(lobby_id, update_data) do
    :gen_statem.call(via_tuple(lobby_id), {:update_bot, update_data}, @default_call_timeout)
  catch
    :exit, {:noproc, _} -> {:error, :invalid_lobby}
  end

  @type lobby_update_data :: %{
          optional(:name) => String.t(),
          optional(:map_name) => String.t(),
          optional(:ally_team_config) => ally_team_config()
        }

  @doc """
  Update lobby properties, like ally team config, names and whatnot
  """
  @spec update_properties(id(), T.userid(), lobby_update_data()) ::
          :ok | {:error, :invalid_lobby | term()}
  def update_properties(lobby_id, user_id, update_data) do
    :gen_statem.call(
      via_tuple(lobby_id),
      {:update_properties, user_id, update_data},
      @default_call_timeout
    )
  catch
    :exit, {:noproc, _} -> {:error, :invalid_lobby}
  end

  @doc """
  This should only be used for tests, because there is some gnarly logic in
  generating the start script and it's a bit hard to test end to end
  """
  @spec get_start_script(id()) :: Autohost.start_script()
  def get_start_script(lobby_id) do
    :gen_statem.call(via_tuple(lobby_id), :get_start_script, @default_call_timeout)
  end

  @spec join_queue(id(), T.userid()) :: :ok | {:error, :invalid_lobby | :not_in_lobby}
  def join_queue(lobby_id, user_id) do
    :gen_statem.call(via_tuple(lobby_id), {:join_queue, user_id}, @default_call_timeout)
  catch
    :exit, {:noproc, _} -> {:error, :invalid_lobby}
  end

  @spec start_battle(id(), T.userid()) ::
          :ok | {:error, reason :: :not_in_lobby | :battle_already_started | term()}
  def start_battle(lobby_id, user_id) do
    :gen_statem.call(via_tuple(lobby_id), {:start_battle, user_id}, @default_call_timeout)
  catch
    :exit, {:noproc, _} -> {:error, :invalid_lobby}
  end

  @impl :gen_statem
  def callback_mode(), do: :handle_event_function

  @impl :gen_statem
  @spec init({id(), {:user, start_params()} | {:snapshot, binary()}}) :: {:ok, term(), state()}
  def init({id, {:user, start_params}}) do
    Process.flag(:trap_exit, true)
    Logger.metadata(actor_type: :lobby, actor_id: id)

    monitors =
      MC.new() |> MC.monitor(start_params.creator_pid, {:user, start_params.creator_data.id})

    state = %{
      id: id,
      monitors: monitors,
      name: start_params.name,
      map_name: start_params.map_name,
      game_version: start_params.game_version,
      engine_version: start_params.engine_version,
      ally_team_config: start_params.ally_team_config,
      players: %{
        start_params.creator_data.id => %{
          id: start_params.creator_data.id,
          name: start_params.creator_data.name,
          password: gen_password(),
          pid: start_params.creator_pid,
          team: {0, 0, 0},
          ready?: false,
          asset_status: :ready
        }
      },
      spectators: %{},
      bot_idx_counter: 0,
      current_battle: nil,
      ids_to_rejoin: MapSet.new()
    }

    TachyonLobby.List.register_lobby(self(), id, get_overview_from_state(state))
    Logger.info("Lobby created by user #{start_params.creator_data.id}")
    {:ok, :running, state}
  end

  def init({id, {:snapshot, serialized_data}}) do
    Process.flag(:trap_exit, true)
    Logger.metadata(actor_type: :lobby, actor_id: id)
    Logger.debug("Restoring lobby from snapshot")

    snapshot = :erlang.binary_to_term(serialized_data)

    player_ids =
      for {id, x} <- snapshot.players, !is_map_key(x, :host_user_id) do
        id
      end

    ids_to_rejoin = MapSet.new(Enum.concat(player_ids, Map.keys(snapshot.spectators)))

    data =
      snapshot
      |> Map.put(:monitors, MC.new())
      |> Map.put(:ids_to_rejoin, ids_to_rejoin)

    timeout = Tachyon.get_restoration_timeout()
    actions = [{:state_timeout, timeout, :snapshot_timeout}]

    {:ok, :starting_up, data, actions}
  end

  @impl :gen_statem
  def handle_event({:call, from}, :get_details, _state, data) do
    {:keep_state, data, [{:reply, from, {:ok, get_details_from_state(data)}}]}
  end

  def handle_event({:call, from}, :get_overview, _state, data) do
    {:keep_state, data, [{:reply, from, get_overview_from_state(data)}]}
  end

  def handle_event({:call, from}, {:rejoin, _user_id, _user_pid}, state, data)
      when state != :starting_up,
      do: {:keep_state, data, [{:reply, from, {:error, :invalid_lobby}}]}

  def handle_event({:call, from}, {:rejoin, user_id, user_pid}, :starting_up, data) do
    if MapSet.member?(data.ids_to_rejoin, user_id) do
      ids_left = MapSet.delete(data.ids_to_rejoin, user_id)

      players =
        if is_map_key(data.players, user_id),
          do: put_in(data.players, [user_id, :pid], user_pid),
          else: data.players

      spectators =
        if is_map_key(data.spectators, user_id),
          do: put_in(data.spectators, [user_id, :pid], user_pid),
          else: data.spectators

      data =
        %{data | players: players, spectators: spectators, ids_to_rejoin: ids_left}
        |> Map.update!(:monitors, &MC.monitor(&1, user_pid, {:user, user_id}))

      actions = [{:reply, from, {:ok, self(), get_details_from_state(data)}}]

      if MapSet.size(ids_left) == 0 do
        Logger.debug("all member rejoined, start up completed")
        TachyonLobby.List.register_lobby(self(), data.id, get_overview_from_state(data))
        {:next_state, :running, data, actions}
      else
        {:keep_state, data, actions}
      end
    else
      {:keep_state, data, [{:reply, from, {:error, :invalid_lobby}}]}
    end
  end

  def handle_event({:call, _from}, _, :starting_up, data) do
    {:keep_state, data, [{:postpone, true}]}
  end

  def handle_event({:call, from}, _, :shutting_down, data) do
    {:keep_state, data, [{:reply, from, {:error, :shutting_down}}]}
  end

  def handle_event({:call, from}, {:join, join_data, _pid}, _state, data)
      when is_map_key(data.players, join_data.id) or is_map_key(data.spectators, join_data.id) do
    {:keep_state, data, [{:reply, from, {:ok, self(), get_details_from_state(data)}}]}
  end

  # 251 is the (current) engine limit for specs + players + bots
  # we also need to enforce this limit on the battle itself, this is where
  # it's actually important. We could theoretically have more than 251
  # lobby members, but it would be rather awkward to only have a subset
  # then in the battle. It's overall simpler to also limit the lobby size
  # (though the members of the lobby may not be the one in the battle itself)
  def handle_event({:call, from}, {:join, _join_data, _pid}, _state, data)
      when map_size(data.spectators) + map_size(data.players) >= 251 do
    {:keep_state, data, [{:reply, from, {:error, :lobby_full}}]}
  end

  def handle_event({:call, from}, {:join, join_data, pid}, _state, data) do
    user_id = join_data.id

    data =
      put_in(data, [:spectators, user_id], %{
        id: user_id,
        name: join_data.name,
        password: gen_password(),
        pid: pid,
        join_queue_position: nil
      })
      |> Map.update!(:monitors, &MC.monitor(&1, pid, {:user, user_id}))

    update = %{join_queue_position: nil}
    broadcast_update({:update, user_id, %{spectators: %{user_id => update}}}, data)

    {:keep_state, data, [{:reply, from, {:ok, self(), get_details_from_state(data)}}]}
  end

  def handle_event({:call, from}, {:leave, user_id}, _state, data)
      when is_map_key(data.players, user_id) do
    case remove_player_from_lobby(user_id, data) do
      data when map_size(data.players) > 0 or map_size(data.spectators) > 0 ->
        {:keep_state, data, [{:reply, from, :ok}]}

      data ->
        {:keep_state, data, [{:reply, from, :ok}, {:next_event, :internal, :empty}]}
    end
  end

  def handle_event({:call, from}, {:leave, user_id}, _state, data)
      when is_map_key(data.spectators, user_id) do
    data = remove_spectator_from_lobby(user_id, data)

    if map_size(data.players) > 0 or map_size(data.spectators) > 0 do
      {:keep_state, data, [{:reply, from, :ok}]}
    else
      {:keep_state, data, [{:reply, from, :ok}, {:next_event, :internal, :empty}]}
    end
  end

  def handle_event({:call, from}, {:leave, _user_id}, _state, data),
    do: {:keep_state, data, [{:reply, from, {:error, :not_in_lobby}}]}

  def handle_event({:call, from}, {:join_ally_team, user_id, _ally_team}, _state, data)
      when not is_map_key(data.players, user_id) and not is_map_key(data.spectators, user_id),
      do: {:keep_state, data, [{:reply, from, {:error, :not_in_lobby}}]}

  def handle_event({:call, from}, {:join_ally_team, user_id, _ally_team}, _state, data)
      when not is_map_key(data.players, user_id) and not is_map_key(data.spectators, user_id),
      do: {:keep_state, data, [{:reply, from, {:error, :not_in_lobby}}]}

  def handle_event({:call, from}, {:join_ally_team, _user_id, ally_team}, _state, data)
      when ally_team >= length(data.ally_team_config) or ally_team < 0,
      do: {:keep_state, data, [{:reply, from, {:error, :invalid_ally_team}}]}

  def handle_event({:call, from}, {:join_ally_team, user_id, ally_team}, _state, data) do
    ally_team_capacity = Enum.at(data.ally_team_config, ally_team).max_teams

    in_team_count = team_count(ally_team, data.players)

    already_there? =
      case data.players[user_id] do
        nil -> false
        %{team: {at, _, _}} -> at == ally_team
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
            data = process_events(events, data).data
            broadcast_updates(events, data)

            {:keep_state, data, [{:reply, from, {:ok, get_details_from_state(data)}}]}

          {false, _s} ->
            # Adding a spec into an ally team. The way we construct the team
            # means it doesn't require any reshuffling of existing players
            events = [{:move_spec_to_player, user_id, %{team: team}}]
            data = process_events(events, data).data
            broadcast_updates(events, data)
            broadcast_player_count_change(data)

            {:keep_state, data, [{:reply, from, {:ok, get_details_from_state(data)}}]}
        end
    end
  end

  def handle_event({:call, from}, {:spectate, user_id}, _state, data)
      when not is_map_key(data.players, user_id) and not is_map_key(data.spectators, user_id),
      do: {:keep_state, data, [{:reply, from, {:error, :not_in_lobby}}]}

  def handle_event({:call, from}, {:spectate, user_id}, _state, data)
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

  def handle_event({:call, from}, {:spectate, user_id}, _state, data)
      when is_map_key(data.players, user_id) do

    events = [
      {:move_player_to_spec, user_id, %{join_queue_position: nil}},
      :repack_players,
      :fill_from_join_queue
    ]

    aggregate = process_events(events, data)
    broadcast_updates(aggregate.updates, aggregate.data)

    {:keep_state, aggregate.data, [{:reply, from, :ok}]}
  end

  def handle_event({:call, from}, {:update_client_status, user_id, _}, _state, data)
      when not is_map_key(data.players, user_id) and not is_map_key(data.spectators, user_id),
      do: {:keep_state, data, [{:reply, from, {:error, :not_in_lobby}}]}

  # maybe we'll want to keep track of client status when they move from player
  # to spec, but for now, just reject the request for non players.
  def handle_event({:call, from}, {:update_client_status, user_id, _}, _state, data)
      when is_map_key(data.spectators, user_id),
      do: {:keep_state, data, [{:reply, from, {:error, :not_a_player}}]}

  def handle_event({:call, from}, {:update_client_status, user_id, update_data}, _state, data) do
    supported_properties = [:ready?, :asset_status]
    event = {:update_client_status, user_id, Map.take(update_data, supported_properties)}
    data = process_events([event], data).data
    broadcast_updates([event], data)
    {:keep_state, data, [{:reply, from, :ok}]}
  end

  def handle_event({:call, from}, {:add_bot, user_id, _add_data}, _state, data)
      when not is_map_key(data.players, user_id) and not is_map_key(data.spectators, user_id),
      do: {:keep_state, data, [{:reply, from, {:error, :not_in_lobby}}]}

  def handle_event({:call, from}, {:add_bot, _user_id, add_data}, _state, data)
      when add_data.ally_team >= length(data.ally_team_config) or add_data.ally_team < 0,
      do: {:keep_state, data, [{:reply, from, {:error, :invalid_ally_team}}]}

  def handle_event({:call, from}, {:add_bot, user_id, add_data}, _state, data) do
    ally_team = add_data.ally_team
    ally_team_capacity = Enum.at(data.ally_team_config, ally_team).max_teams

    in_team_count = team_count(ally_team, data.players)

    if in_team_count >= ally_team_capacity do
      {:keep_state, data, [{:reply, from, {:error, :ally_team_full}}]}
    else
      bot_id = "bot-#{data.bot_idx_counter}"

      bot = %{
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

  def handle_event({:call, from}, {:remove_bot, bot_id}, _state, data)
      when not is_map_key(data.players, bot_id),
      do: {:keep_state, data, [{:reply, from, {:error, :invalid_bot_id}}]}

  def handle_event({:call, from}, {:remove_bot, bot_id}, _state, data) do
    events = [{:remove_player_from_lobby, bot_id}, :repack_players, :fill_from_join_queue]
    aggregate = process_events(events, data)
    broadcast_updates(aggregate.updates, aggregate.data)

    {:keep_state, data, [{:reply, from, :ok}]}
  end

  def handle_event({:call, from}, {:update_bot, %{id: bot_id}}, _state, data)
      when not is_map_key(data.players, bot_id),
      do: {:keep_state, data, [{:reply, from, {:error, :invalid_bot_id}}]}

  def handle_event({:call, from}, {:update_bot, %{id: bot_id} = update_data}, _state, data) do
    patch_merge(data.players[bot_id], update_data)
    data = update_in(data.players[bot_id], &patch_merge(&1, update_data))
    broadcast_update({:update, nil, %{players: %{bot_id => update_data}}}, data)
    {:keep_state, data, [{:reply, from, :ok}]}
  end

  def handle_event({:call, from}, {:update_properties, _, data}, _state, fsm_data)
      when map_size(data) == 0,
      do: {:keep_state, fsm_data, [{:reply, from, :ok}]}

  def handle_event({:call, from}, {:update_properties, user_id, data}, _state, fsm_data) do
    {final_data, events, errors} =
      Enum.reduce(data, {fsm_data, [], []}, fn {k, v}, {data, events, errors} ->
        case update_property(k, v, data, user_id) do
          {:error, msg} ->
            {data, events, [msg | errors]}

          {:ok, new_events} ->
            updated_data = process_events(new_events, data).data
            {updated_data, events ++ new_events, errors}
        end
      end)

    if Enum.empty?(errors) do
      broadcast_updates(events, final_data)
      broadcast_list_updates(events, fsm_data, final_data)
      {:keep_state, final_data, [{:reply, from, :ok}]}
    else
      message = Enum.join(errors, ", ")
      {:keep_state, fsm_data, [{:reply, from, {:error, "Cannot update lobby: #{message}"}}]}
    end
  end

  def handle_event({:call, from}, {:join_queue, user_id}, _state, data)
      when not is_map_key(data.players, user_id) and not is_map_key(data.spectators, user_id),
      do: {:keep_state, data, [{:reply, from, {:error, :not_in_lobby}}]}

  def handle_event({:call, from}, {:join_queue, user_id}, _state, data) do
    cond do
      # already in the join queue, do nothing. This avoid someone
      # losing their position if they fat-finger the button
      get_in(data.spectators[user_id].join_queue_position) != nil ->
        {:keep_state, data, [{:reply, from, :ok}]}

      # there is no one in the join queue. So going into the join queue will immediately put
      # the player back into an ally team. Although they may end up in a different ally team
      # it is largely useless, so for simplicity sake, ignore the join_queue command
      is_map_key(data.players, user_id) and
          Enum.all?(data.spectators, fn {_, s} -> s.join_queue_position == nil end) ->
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

        data = process_events(events, data).data
        broadcast_updates(events, data)

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
              initial_state = data
              events = [{:move_spec_to_player, user_id, %{team: team}}]
              data = process_events(events, data).data
              broadcast_updates(events, data)
              broadcast_list_updates(events, initial_state, data)
          end

        {:keep_state, data, [{:reply, from, :ok}]}
    end
  end

  def handle_event({:call, from}, {:start_battle, user_id}, _state, data)
      when not is_map_key(data.players, user_id) and not is_map_key(data.spectators, user_id),
      do: {:keep_state, data, [{:reply, from, {:error, :not_in_lobby}}]}

  def handle_event({:call, from}, {:start_battle, _user_id}, _state, data)
      when data.current_battle != nil,
      do: {:keep_state, data, [{:reply, from, {:error, :battle_already_started}}]}

  def handle_event({:call, from}, {:start_battle, _user_id}, _state, data) do
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
          do: Player.lobby_battle_start(p_id, battle_data, start_data, p.password)

      now = DateTime.utc_now()

      data =
        %{data | current_battle: %{id: battle_id, started_at: now}}
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

  def handle_event({:call, from}, :get_start_script, _state, data),
    do: {:keep_state, data, [{:reply, from, gen_start_script(data)}]}

  def handle_event(:info, {:DOWN, ref, :process, _pid, :shutdown}, state, data) do
    val = MC.get_val(data.monitors, ref)
    data = Map.update!(data, :monitors, &MC.demonitor_by_val(&1, val))

    case state do
      :shutting_down -> {:keep_state, data}
      _ -> {:next_state, :shutting_down, data}
    end
  end

  # only DOWN events matter when shutting down the lobby, everything else should be ignored
  def handle_event(:info, _, :shutting_down, data) do
    {:keep_state, data}
  end

  def handle_event(:info, {:DOWN, ref, :process, _obj, reason}, _state, data) do
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

  def handle_event(:info, {:EXIT, _pid, reason}, _state, _data) do
    {:stop, reason}
  end

  def handle_event(:internal, :empty, _state, data) do
    Logger.info("Lobby shutting down because empty")
    {:stop, {:shutdown, :empty}, data}
  end

  def handle_event(:state_timeout, :snapshot_timeout, :starting_up, data) do
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
          for {k, v} <- ps, into: %{}, do: {k, Map.delete(v, :pid)}
        end)
        |> Map.update!(:spectators, fn ps ->
          for {k, v} <- ps, into: %{}, do: {k, Map.delete(v, :pid)}
        end)
        |> :erlang.term_to_binary()

      Teiserver.KvStore.put("lobby", data.id, to_save)
    end
  end

  def terminate(_reason, _state, _data), do: nil

  @spec via_tuple(id()) :: GenServer.name()
  defp via_tuple(lobby_id) do
    TachyonLobby.Registry.via_tuple(lobby_id)
  end

  @spec get_overview_from_state(state :: state()) :: TachyonLobby.List.overview()
  defp get_overview_from_state(state) do
    %{
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
      current_battle: nil
    }
  end

  @spec get_details_from_state(state()) :: details()
  defp get_details_from_state(state) do
    {players, bots} = Enum.split_with(state.players, fn {_, p} -> is_map_key(p, :pid) end)

    players =
      Enum.map(players, fn {p_id, p} ->
        {p_id, Map.take(p, [:team, :ready?, :asset_status])}
      end)
      |> Enum.into(%{})

    spectators =
      Enum.map(state.spectators, fn {s_id, s} ->
        {s_id, %{join_queue_position: s.join_queue_position}}
      end)
      |> Enum.into(%{})

    Map.take(state, [
      :id,
      :name,
      :map_name,
      :game_version,
      :engine_version,
      :ally_team_config,
      :current_battle
    ])
    |> Map.put(:players, players)
    |> Map.put(:spectators, spectators)
    |> Map.put(:bots, Map.new(bots))
  end

  # Given a list of events to process (in the event sourcing way) and the initial
  # state to apply these events to, returns the final state alongside any
  # potential update events that should also be broadcasted to members
  @typep aggregate :: %{data: state(), updates: [event()]}
  @spec process_events([event()], state()) :: aggregate()
  defp process_events(events, state),
    do: Enum.reduce(events, %{data: state, updates: []}, &process_event/2)

  @spec process_event(event(), %{data: state(), updates: [event()]}) :: %{
          data: state(),
          updates: [event()]
        }
  defp process_event({:move_player, p_id, team} = ev, aggregate) do
    aggregate
    |> update_in([:data, :players, p_id], fn p ->
      Map.merge(p, %{team: team, ready?: false, asset_status: :ready})
    end)
    |> update_in([:updates], &[ev | &1])
  end

  defp process_event({:remove_player_from_lobby, p_id} = ev, aggregate) do
    aggregate
    |> update_in([:data, :players], &Map.delete(&1, p_id))
    |> update_in([:data, :monitors], &MC.demonitor_by_val(&1, {:user, p_id}))
    |> update_in([:updates], &[ev | &1])
  end

  defp process_event({:remove_spec_from_lobby, s_id} = ev, aggregate) do
    aggregate
    |> update_in([:data, :spectators], &Map.delete(&1, s_id))
    |> update_in([:data, :monitors], &MC.demonitor_by_val(&1, {:user, s_id}))
    |> update_in([:updates], &[ev | &1])
  end

  defp process_event({:move_spec_to_player, p_id, player_data} = ev, aggregate) do
    player_data = Map.merge(%{ready?: false, asset_status: :ready}, player_data)

    player =
      Map.merge(aggregate.data.spectators[p_id], player_data)
      |> Map.delete(:join_queue_position)

    aggregate
    |> update_in([:data, :spectators], &Map.delete(&1, p_id))
    |> put_in([:data, :players, p_id], player)
    |> update_in([:updates], &[ev | &1])
  end

  defp process_event({:move_player_to_spec, p_id, spec_data} = ev, aggregate) do
    spec =
      Map.merge(aggregate.data.players[p_id], spec_data)
      |> Map.delete(:team)

    aggregate
    |> update_in([:data, :players], &Map.delete(&1, p_id))
    |> put_in([:data, :spectators, p_id], spec)
    |> update_in([:updates], &[ev | &1])
  end

  # given a state where the players may not be all on consecutive ally team and
  # teams, re-assign all required player.team so that they are all consecutive
  # player should never change ally team when doing so, only teams
  # and since archon isn't really supported, this ends up only repacking the teams
  defp process_event(:repack_players, aggregate) do
    data = aggregate.data

    repacked_players =
      for {_at, at_idx} <- Enum.with_index(data.ally_team_config) do
        Enum.filter(data.players, fn {_, %{team: {p_at, _, _}}} -> at_idx == p_at end)
        |> Enum.map(fn {_, p} -> p end)
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
    |> put_in([:data, :players], repacked_players)
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
    |> update_in([:data, :players, p_id], &Map.merge(&1, changes))
    |> update_in([:updates], &[ev | &1])
  end

  defp process_event({:update_lobby_name, new_name} = ev, aggregate) do
    aggregate
    |> put_in([:data, :name], new_name)
    |> update_in([:updates], &[ev | &1])
  end

  defp process_event({:update_map_name, new_name} = ev, aggregate) do
    aggregate
    |> put_in([:data, :map_name], new_name)
    |> update_in([:updates], &[ev | &1])
  end

  defp process_event({:update_ally_team_config, _, new_config} = ev, aggregate) do
    aggregate
    |> put_in([:data, :ally_team_config], new_config)
    |> update_in([:updates], &[ev | &1])
  end

  # avoid sending a useless lobby list update when the last member of the lobby
  # just left. The caller of this function will detect the lobby is empty and
  # terminate the process, which will trigger the final lobby list update for
  # this lobby
  @spec broadcast_updates([event()], state()) :: state()
  defp broadcast_updates(_events, state)
       when map_size(state.players) == 0 and map_size(state.spectators) == 0,
       do: state

  defp broadcast_updates(events, state) do
    change_map = Enum.reduce(events, %{}, &update_change_from_event/2)

    broadcast_update({:update, nil, change_map}, state)
    state
  end

  defp update_change_from_event({:move_player, p_id, team}, change_map) do
    change_map
    |> Map.put_new(:players, %{})
    |> Map.update!(:players, fn players ->
      players
      |> Map.put_new(p_id, %{})
      |> update_in([p_id], fn p ->
        Map.merge(%{team: team, ready?: false, asset_status: :ready}, p)
      end)
    end)
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
    player_data = Map.merge(%{ready?: false, asset_status: :ready}, player_data)

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
      Teiserver.Helpers.Collections.zip_with_padding(old_config, new_config, nil)
      |> Enum.map(fn
        {_old_at, nil} ->
          nil

        {nil, new_at} ->
          new_at

        {old_at, new_at} ->
          Map.update!(new_at, :teams, fn new_teams ->
            Teiserver.Helpers.Collections.zip_with_padding(old_at.teams, new_teams, nil)
            |> Enum.map(fn {_old_team, new_team} -> new_team end)
          end)
      end)

    Map.put(change_map, :ally_team_config, changes)
  end

  defp broadcast_list_updates(_events, _starting_state, final_state)
       when map_size(final_state.players) == 0 and map_size(final_state.spectators) == 0,
       do: final_state

  defp broadcast_list_updates(events, starting_state, final_state) do
    change_map =
      Enum.reduce(events, %{}, fn ev, change_map ->
        case ev do
          {:update_lobby_name, new_name} ->
            Map.put(change_map, :name, new_name)

          {:update_map_name, new_name} ->
            Map.put(change_map, :map_name, new_name)

          {:update_ally_team_config, _, new_config} ->
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
            |> Map.put(:player_count, map_size(final_state.players))

          _ ->
            change_map
        end
      end)

    change_map =
      if map_size(starting_state.players) != map_size(final_state.players) do
        Map.put(change_map, :player_count, map_size(final_state.players))
      else
        change_map
      end

    if change_map != %{}, do: TachyonLobby.List.update_lobby(final_state.id, change_map)
    final_state
  end

  # find an empty slot for a player/bot to play
  # this function isn't too efficient, but it's never going to be run on
  # massive inputs since the engine cannot support more than 254 players anyway
  @spec find_team(ally_team_config(), %{player_id() => player() | bot()}) :: team() | nil
  defp find_team(ally_team_config, players) do
    # find the least full ally team
    ally_team =
      for {at, at_idx} <- Enum.with_index(ally_team_config) do
        total_capacity = Enum.sum_by(at.teams, fn t -> t.max_players end)

        capacity = total_capacity - team_count(at_idx, players)
        {capacity, at_idx, at.teams}
      end
      |> Enum.filter(fn {c, _, _} -> c > 0 end)
      # select the biggest capacity with the lowest index
      |> Enum.min(
        fn {c1, idx1, _}, {c2, idx2, _} ->
          c1 >= c2 && idx1 <= idx2
        end,
        fn -> nil end
      )

    case ally_team do
      nil ->
        nil

      {_, at_idx, teams} ->
        {_, t_idx, p_idx} =
          for {t, t_idx} <- Enum.with_index(teams) do
            player_count =
              Enum.count(players, fn {_, %{team: {x, y, _}}} ->
                x == at_idx && y == t_idx
              end)

            capacity = t.max_players - player_count
            {capacity, t_idx, player_count}
          end
          |> Enum.filter(fn {c, _, _} -> c > 0 end)
          # guarantee not to raise an exception
          |> Enum.min()

        {at_idx, t_idx, p_idx}
    end
  end

  # return the number of players + bots in the given ally team
  defp team_count(ally_team, players) do
    Enum.count(players, fn {_, %{team: {at, _, _}}} -> at == ally_team end)
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

  defp broadcast_player_count_change(state) do
    if not Enum.empty?(state.players) or not Enum.empty?(state.spectators) do
      count = Enum.count(state.players, fn {_, p} -> Map.get(p, :pid) != nil end)
      TachyonLobby.List.update_lobby(state.id, %{player_count: count})
    end

    state
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
      Enum.reduce(spectators, nil, fn {_, s}, max_so_far ->
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
    Enum.reduce(spectators, {nil, nil}, fn {id, s}, {min_so_far, _} = acc ->
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

  @spec remove_player_from_lobby(T.userid(), state()) :: state()
  defp remove_player_from_lobby(user_id, state) do
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

    aggregate = process_events(events, state)

    broadcast_updates(aggregate.updates, aggregate.data)
    broadcast_player_count_change(aggregate.data)
  end

  @spec remove_spectator_from_lobby(T.userid(), state()) :: state()
  defp remove_spectator_from_lobby(user_id, state) do
    bot_ids_to_remove =
      Enum.filter(state.players, fn {_bot_id, b} -> Map.get(b, :host_user_id) == user_id end)
      |> Enum.map(&elem(&1, 0))

    events =
      Enum.map(bot_ids_to_remove, fn id -> {:remove_player_from_lobby, id} end) ++
        [{:remove_spec_from_lobby, user_id}, :repack_players, :fill_from_join_queue]

    aggregate = process_events(events, state)

    broadcast_updates(aggregate.updates, aggregate.data)
    broadcast_player_count_change(aggregate.data)
  end

  # Add the first player from the join queue to the player list and returns the
  # updated state alongside the player id that was added
  # {state(), T.userid() | nil}
  @spec add_player_from_join_queue(state()) :: event() | nil
  defp add_player_from_join_queue(state) do
    player_to_add =
      case get_first_player_in_join_queue(state.spectators) do
        nil ->
          nil

        id ->
          case find_team(state.ally_team_config, state.players) do
            nil ->
              nil

            team ->
              {id, %{team: team, ready?: false, asset_status: :ready}}
          end
      end

    case player_to_add do
      nil ->
        nil

      {id, player_data} ->
        {:move_spec_to_player, id, player_data}
    end
  end

  defp fill_players_from_join_queue(state, events \\ []) do
    case add_player_from_join_queue(state) do
      nil ->
        {state, Enum.reverse(events)}

      event ->
        state = process_event(event, %{data: state, updates: []}).data
        fill_players_from_join_queue(state, [event | events])
    end
  end

  defp gen_password(), do: :crypto.strong_rand_bytes(16) |> Base.encode16()

  # in tests, some user ids are string
  defp bot_id?(id) when is_integer(id), do: false
  defp bot_id?(id), do: String.starts_with?(id, "bot")

  @spec gen_start_script(state()) :: Autohost.start_script()
  defp gen_start_script(state) do
    sorted =
      Map.values(state.players)
      |> Enum.sort_by(& &1.team)
      |> Enum.group_by(&elem(&1.team, 0))
      |> Map.values()

    ally_teams =
      for {at, at_config} <- Enum.zip(sorted, state.ally_team_config) do
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
              for bot <- bots do
                %{
                  host_user_id: bot.host_user_id,
                  name: Map.get(bot, :name),
                  ai_short_name: bot.short_name,
                  ai_version: Map.get(bot, :version),
                  ai_options: bot.options
                }
                |> Enum.reject(fn {_, v} -> v == nil || v == %{} end)
                |> Map.new()
              end

            %{players: players, bots: bots} |> Enum.reject(&Enum.empty?(elem(&1, 1))) |> Map.new()
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
  end

  @spec update_property(atom(), term(), state(), T.userid()) ::
          {:ok, [event()]} | {:error, String.t()}
  defp update_property(:name, new_name, _state, _user_id) do
    # we can expand lobby name validation later
    if new_name == "" do
      {:error, "name must not be empty"}
    end

    {:ok, [{:update_lobby_name, new_name}]}
  end

  defp update_property(:map_name, new_name, _state, _user_id),
    do: {:ok, [{:update_map_name, new_name}]}

  defp update_property(:ally_team_config, new_config, state, _user_id) do
    spec_ids =
      Enum.map(state.players, fn {p_id, %{team: {x, y, z}}} ->
        with at_config when not is_nil(at_config) <- Enum.at(new_config, x),
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

    remove_events = [
      {:update_ally_team_config, state.ally_team_config, new_config} | spec_events ++ bot_events
    ]

    state = process_events(remove_events, state).data

    {_final_state, add_events} = fill_players_from_join_queue(state)

    # We put players in join queue, and then fill the teams with
    # the join queue, which means we can have events like
    # :move_player_to_spec and later :move_spec_to_player
    # which would generate an update with %{spectators: %{x => nil}}
    # where x was never a spectator to beging with.
    # So we need to detect these events and replace the pair with a :move_player
    # event instead.
    added_ids = Enum.map(add_events, fn {:move_spec_to_player, id, _} -> id end)

    ids_to_fix = MapSet.intersection(MapSet.new(player_ids), MapSet.new(added_ids))

    final_events =
      Enum.map(remove_events ++ add_events, fn ev ->
        case ev do
          {:move_player_to_spec, x, _} ->
            if MapSet.member?(ids_to_fix, x),
              do: nil,
              else: ev

          {:move_spec_to_player, x, data} ->
            if MapSet.member?(ids_to_fix, x),
              do: {:move_player, x, data.team},
              else: ev

          _ ->
            ev
        end
      end)
      |> Enum.reject(&is_nil/1)

    {:ok, final_events}
  end

  defp update_property(prop, _, _, _), do: {:error, "update #{prop} is not supported"}

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
