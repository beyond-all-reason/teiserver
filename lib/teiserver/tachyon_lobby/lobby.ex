defmodule Teiserver.TachyonLobby.Lobby do
  @moduledoc """
  Represent a single lobby
  """

  require Logger

  # lobby process holds transient state about a specific lobby. If this process
  # goes down, there is no point restarting since the state will be lost
  use GenServer, restart: :temporary

  alias Teiserver.Asset
  alias Teiserver.Autohost
  alias Teiserver.Data.Types, as: T
  alias Teiserver.Helpers.MonitorCollection, as: MC
  alias Teiserver.Player
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
            T.userid() => %{team: team()}
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
           team: team()
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
               }
         }

  # the list of events used by the various internal functions
  # a player (user or bot) changes team
  @typep event ::
           {:move_player, player_id(), team()}
           | {:remove_player_from_lobby, player_id()}
           | {:remove_spec_from_lobby, T.userid()}
           | {:move_spec_to_player, T.userid(), player_data :: map()}
           | {:move_player_to_spec, T.userid(), spec_data :: map()}
           | {:update_lobby_name, new_name :: String.t()}
           | {:update_map_name, new_name :: String.t()}
           | {:update_ally_team_config, new_config :: ally_team_config()}

  @spec gen_id() :: id()
  def gen_id(), do: UUID.uuid4()

  # note: this uses a pid and not a lobby id because it's (currently) only
  # used by the lobby list process to bootstrap its state, and at that time
  # it has the pid (from the registry).
  # but if the needs arise, this could be overloaded to use a lobby id
  # and the usual via_tuple mechanism
  @spec get_overview(pid()) :: TachyonLobby.List.overview() | nil
  def get_overview(lobby_pid) do
    GenServer.call(lobby_pid, :get_overview)
  catch
    :exit, {:noproc, _} -> nil
  end

  @spec get_details(id()) :: {:ok, details()} | {:error, reason :: term()}
  def get_details(id) do
    GenServer.call(via_tuple(id), :get_details)
  catch
    :exit, {:noproc, _} -> {:error, :invalid_battle}
  end

  @spec start_link({id(), start_params()}) :: GenServer.on_start()
  def start_link({id, _start_params} = args) do
    GenServer.start_link(__MODULE__, args, name: via_tuple(id))
  end

  @spec join(id(), player_join_data(), pid()) ::
          {:ok, lobby_pid :: pid(), details()} | {:error, reason :: term()}
  def join(lobby_id, join_data, pid \\ self()) do
    GenServer.call(via_tuple(lobby_id), {:join, join_data, pid})
  catch
    :exit, {:noproc, _} -> {:error, :invalid_lobby}
  end

  @spec leave(id(), T.userid()) :: :ok | {:error, reason :: :lobby_full | term()}
  def leave(lobby_id, user_id) do
    GenServer.call(via_tuple(lobby_id), {:leave, user_id})
  catch
    :exit, {:noproc, _} -> {:error, :invalid_lobby}
  end

  @spec join_ally_team(id(), T.userid(), allyTeam :: non_neg_integer()) ::
          {:ok, details()}
          | {:error,
             reason :: :invalid_lobby | :not_in_lobby | :invalid_ally_team | :ally_team_full}
  def join_ally_team(lobby_id, user_id, ally_team) do
    GenServer.call(via_tuple(lobby_id), {:join_ally_team, user_id, ally_team})
  catch
    :exit, {:noproc, _} -> {:error, :invalid_lobby}
  end

  @spec spectate(id(), T.userid()) :: :ok | {:error, :invalid_lobby | :not_in_lobby}
  def spectate(lobby_id, user_id) do
    GenServer.call(via_tuple(lobby_id), {:spectate, user_id})
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
    GenServer.call(
      via_tuple(lobby_id),
      {:add_bot, user_id,
       %{
         ally_team: ally_team,
         short_name: short_name,
         name: opts[:name],
         version: opts[:version],
         options: Keyword.get(opts, :options, %{})
       }}
    )
  catch
    :exit, {:noproc, _} -> {:error, :invalid_lobby}
  end

  @spec remove_bot(id(), bot_id :: String.t()) :: :ok | {:error, :invalid_bot_id | term()}
  def remove_bot(lobby_id, bot_id) do
    GenServer.call(via_tuple(lobby_id), {:remove_bot, bot_id})
  catch
    :exit, {:noproc, _} -> {:error, :invalid_lobby}
  end

  @spec update_bot(id(), bot_update_data()) :: :ok | {:error, reason :: :invalid_bot_id | term()}
  def update_bot(lobby_id, update_data) do
    GenServer.call(via_tuple(lobby_id), {:update_bot, update_data})
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
    GenServer.call(via_tuple(lobby_id), {:update_properties, user_id, update_data})
  catch
    :exit, {:noproc, _} -> {:error, :invalid_lobby}
  end

  @doc """
  This should only be used for tests, because there is some gnarly logic in
  generating the start script and it's a bit hard to test end to end
  """
  @spec get_start_script(id()) :: TachyonBattle.start_script()
  def get_start_script(lobby_id) do
    GenServer.call(via_tuple(lobby_id), :get_start_script)
  end

  @spec join_queue(id(), T.userid()) :: :ok | {:error, :invalid_lobby | :not_in_lobby}
  def join_queue(lobby_id, user_id) do
    GenServer.call(via_tuple(lobby_id), {:join_queue, user_id})
  catch
    :exit, {:noproc, _} -> {:error, :invalid_lobby}
  end

  @spec start_battle(id(), T.userid()) ::
          :ok | {:error, reason :: :not_in_lobby | :battle_already_started | term()}
  def start_battle(lobby_id, user_id) do
    GenServer.call(via_tuple(lobby_id), {:start_battle, user_id})
  catch
    :exit, {:noproc, _} -> {:error, :invalid_lobby}
  end

  @impl true
  @spec init({id(), start_params()}) :: {:ok, state()}
  def init({id, start_params}) do
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
          team: {0, 0, 0}
        }
      },
      spectators: %{},
      bot_idx_counter: 0,
      current_battle: nil
    }

    TachyonLobby.List.register_lobby(self(), id, get_overview_from_state(state))
    Logger.info("Lobby created by user #{start_params.creator_data.id}")
    {:ok, state}
  end

  @impl true
  def handle_call(:get_details, _from, state) do
    {:reply, {:ok, get_details_from_state(state)}, state}
  end

  def handle_call(:get_overview, _from, state) do
    {:reply, get_overview_from_state(state), state}
  end

  def handle_call({:join, join_data, _pid}, _from, state)
      when is_map_key(state.players, join_data.id) or is_map_key(state.spectators, join_data.id) do
    {:reply, {:ok, self(), get_details_from_state(state)}, state}
  end

  # 251 is the (current) engine limit for specs + players + bots
  # we also need to enforce this limit on the battle itself, this is where
  # it's actually important. We could theoretically have more than 251
  # lobby members, but it would be rather awkward to only have a subset
  # then in the battle. It's overall simpler to also limit the lobby size
  # (though the members of the lobby may not be the one in the battle itself)
  def handle_call({:join, _join_data, _pid}, _from, state)
      when map_size(state.spectators) + map_size(state.players) >= 251 do
    {:reply, {:error, :lobby_full}, state}
  end

  def handle_call({:join, join_data, pid}, _from, state) do
    user_id = join_data.id

    state =
      put_in(state, [:spectators, user_id], %{
        id: user_id,
        name: join_data.name,
        password: gen_password(),
        pid: pid,
        join_queue_position: nil
      })
      |> Map.update!(:monitors, &MC.monitor(&1, pid, {:user, user_id}))

    update = %{join_queue_position: nil}
    broadcast_update({:update, user_id, %{spectators: %{user_id => update}}}, state)

    {:reply, {:ok, self(), get_details_from_state(state)}, state}
  end

  def handle_call({:leave, user_id}, _from, state) when is_map_key(state.players, user_id) do
    case remove_player_from_lobby(user_id, state) do
      state when map_size(state.players) > 0 or map_size(state.spectators) > 0 ->
        {:reply, :ok, state}

      state ->
        {:reply, :ok, state, {:continue, :empty}}
    end
  end

  def handle_call({:leave, user_id}, _from, state) when is_map_key(state.spectators, user_id) do
    state = remove_spectator_from_lobby(user_id, state)

    if map_size(state.players) > 0 or map_size(state.spectators) > 0 do
      {:reply, :ok, state}
    else
      {:reply, :ok, state, {:continue, :empty}}
    end
  end

  def handle_call({:leave, _user_id}, _from, state), do: {:reply, {:error, :not_in_lobby}, state}

  def handle_call({:join_ally_team, user_id, _ally_team}, _from, state)
      when not is_map_key(state.players, user_id) and not is_map_key(state.spectators, user_id),
      do: {:reply, {:error, :not_in_lobby}, state}

  def handle_call({:join_ally_team, user_id, _ally_team}, _from, state)
      when not is_map_key(state.players, user_id) and not is_map_key(state.spectators, user_id),
      do: {:reply, {:error, :not_in_lobby}, state}

  def handle_call({:join_ally_team, _user_id, ally_team}, _from, state)
      when ally_team >= length(state.ally_team_config) or ally_team < 0,
      do: {:reply, {:error, :invalid_ally_team}, state}

  def handle_call({:join_ally_team, user_id, ally_team}, _from, state) do
    ally_team_capacity = Enum.at(state.ally_team_config, ally_team).max_teams

    in_team_count = team_count(ally_team, state.players)

    already_there? =
      case state.players[user_id] do
        nil -> false
        %{team: {at, _, _}} -> at == ally_team
      end

    cond do
      already_there? ->
        {:reply, {:ok, get_details_from_state(state)}, state}

      in_team_count >= ally_team_capacity ->
        {:reply, {:error, :ally_team_full}, state}

      true ->
        # we guarantee that teams are consecutive in the ally team (without gap)
        # so we can use the in_team_count as the index for the new team in the ally team
        team = {ally_team, in_team_count, 0}

        case {is_map_key(state.players, user_id), state.spectators[user_id]} do
          {true, nil} ->
            # we're moving a player from a different ally team
            remove_events = do_remove_player(user_id, state.players)
            events = [{:move_player, user_id, team} | remove_events]

            state = new_state_from_events(events, state)
            broadcast_updates(remove_events, state)

            {:reply, {:ok, get_details_from_state(state)}, state}

          {false, _s} ->
            # Adding a spec into an ally team. The way we construct the team
            # means it doesn't require any reshuffling of existing players
            # player = s |> Map.delete(:join_queue_position) |> Map.put(:team, team)
            events = [{:move_spec_to_player, user_id, %{team: team}}]
            state = new_state_from_events(events, state)
            broadcast_updates(events, state)
            broadcast_player_count_change(state)

            {:reply, {:ok, get_details_from_state(state)}, state}
        end
    end
  end

  def handle_call({:spectate, user_id}, _from, state)
      when not is_map_key(state.players, user_id) and not is_map_key(state.spectators, user_id),
      do: {:reply, {:error, :not_in_lobby}, state}

  def handle_call({:spectate, user_id}, _from, state)
      when is_map_key(state.spectators, user_id) do
    if state.spectators[user_id].join_queue_position == nil do
      {:reply, :ok, state}
    else
      state = put_in(state.spectators[user_id].join_queue_position, nil)
      update = %{spectators: %{user_id => %{join_queue_position: nil}}}
      broadcast_update({:update, nil, update}, state)
      {:reply, :ok, state}
    end
  end

  def handle_call({:spectate, user_id}, _from, state) when is_map_key(state.players, user_id) do
    remove_events = do_remove_player(user_id, state.players)

    events = [{:move_player_to_spec, user_id, %{join_queue_position: nil}} | remove_events]
    state = new_state_from_events(events, state)

    {events, state} =
      case add_player_from_join_queue(state) do
        nil -> {events, state}
        ev -> {[ev | events], new_state_from_events([ev], state)}
      end

    broadcast_updates(events, state)

    {:reply, :ok, state}
  end

  def handle_call({:add_bot, user_id, _add_data}, _from, state)
      when not is_map_key(state.players, user_id) and not is_map_key(state.spectators, user_id),
      do: {:reply, {:error, :not_in_lobby}, state}

  def handle_call({:add_bot, _user_id, add_data}, _from, state)
      when add_data.ally_team >= length(state.ally_team_config) or add_data.ally_team < 0,
      do: {:reply, {:error, :invalid_ally_team}, state}

  def handle_call({:add_bot, user_id, add_data}, _from, state) do
    ally_team = add_data.ally_team
    ally_team_capacity = Enum.at(state.ally_team_config, ally_team).max_teams

    in_team_count = team_count(ally_team, state.players)

    if in_team_count >= ally_team_capacity do
      {:reply, {:error, :ally_team_full}, state}
    else
      bot_id = "bot-#{state.bot_idx_counter}"

      bot = %{
        id: bot_id,
        team: {ally_team, in_team_count, 0},
        host_user_id: user_id,
        short_name: add_data.short_name,
        name: add_data.name,
        version: add_data.version,
        options: add_data.options
      }

      state =
        put_in(state.players[bot.id], bot)
        |> Map.update!(:bot_idx_counter, &(&1 + 1))

      broadcast_update({:update, nil, %{players: %{bot.id => bot}}}, state)

      {:reply, {:ok, bot.id}, state}
    end
  end

  def handle_call({:remove_bot, bot_id}, _from, state) when not is_map_key(state.players, bot_id),
    do: {:reply, {:error, :invalid_bot_id}, state}

  def handle_call({:remove_bot, bot_id}, _from, state) do
    events = do_remove_player(bot_id, state.players)
    events = [{:remove_player_from_lobby, bot_id} | events]
    state = new_state_from_events(events, state)

    {events, state} =
      case add_player_from_join_queue(state) do
        nil -> {events, state}
        ev -> {[ev | events], new_state_from_events([ev], state)}
      end

    broadcast_updates(events, state)

    {:reply, :ok, state}
  end

  def handle_call({:update_bot, %{id: bot_id}}, _from, state)
      when not is_map_key(state.players, bot_id),
      do: {:reply, {:error, :invalid_bot_id}, state}

  def handle_call({:update_bot, %{id: bot_id} = update_data}, _from, state) do
    patch_merge(state.players[bot_id], update_data)
    state = update_in(state.players[bot_id], &patch_merge(&1, update_data))
    broadcast_update({:update, nil, %{players: %{bot_id => update_data}}}, state)
    {:reply, :ok, state}
  end

  def handle_call({:update_properties, _, data}, _from, state) when map_size(data) == 0,
    do: {:reply, :ok, state}

  def handle_call({:update_properties, _user_id, data}, _from, state) do
    {final_state, events, errors} =
      Enum.reduce(data, {state, [], []}, fn {k, v}, {state, events, errors} ->
        case update_property(k, v, state) do
          {:error, msg} ->
            {state, events, [msg | errors]}

          {:ok, new_events} ->
            updated_state = new_state_from_events(new_events, state)
            {updated_state, events ++ new_events, errors}
        end
      end)

    if Enum.empty?(errors) do
      broadcast_updates(events, final_state)
      broadcast_list_updates(events, state, final_state)
      {:reply, :ok, final_state}
    else
      message = Enum.join(errors, ", ")
      {:reply, {:error, "Cannot update lobby: #{message}"}, state}
    end
  end

  def handle_call({:join_queue, user_id}, _from, state)
      when not is_map_key(state.players, user_id) and not is_map_key(state.spectators, user_id),
      do: {:reply, {:error, :not_in_lobby}, state}

  def handle_call({:join_queue, user_id}, _from, state) do
    cond do
      # already in the join queue, do nothing. This avoid someone
      # losing their position if they fat-finger the button
      get_in(state.spectators[user_id].join_queue_position) != nil ->
        {:reply, :ok, state}

      # there is no one in the join queue. So going into the join queue will immediately put
      # the player back into an ally team. Although they may end up in a different ally team
      # it is largely useless, so for simplicity sake, ignore the join_queue command
      is_map_key(state.players, user_id) and
          Enum.count(state.spectators, fn {_, s} -> s.join_queue_position != nil end) == 0 ->
        {:reply, :ok, state}

      # swap the player with the first in the join queue
      is_map_key(state.players, user_id) ->
        # TODO: swap the player with the first in the join queue + corresponding updates
        s_id = get_first_player_in_join_queue(state.spectators)
        player = state.players[user_id]
        pos = find_spec_queue_pos(state.spectators)

        events = [
          {:move_spec_to_player, s_id, %{team: player.team}},
          {:move_player_to_spec, user_id, %{join_queue_position: pos}}
        ]

        state = new_state_from_events(events, state)
        broadcast_updates(events, state)

        {:reply, :ok, state}

      # spec getting into the join queue
      true ->
        state =
          case find_team(state.ally_team_config, state.players) do
            nil ->
              pos = find_spec_queue_pos(state.spectators)

              state =
                update_in(state.spectators[user_id], fn s ->
                  s |> Map.put(:join_queue_position, pos)
                end)

              update = %{spectators: %{user_id => %{join_queue_position: pos}}}
              broadcast_update({:update, nil, update}, state)

            team ->
              events = [{:move_spec_to_player, user_id, %{team: team}}]
              state = new_state_from_events(events, state)
              broadcast_updates(events, state)
          end

        {:reply, :ok, state}
    end
  end

  def handle_call({:start_battle, user_id}, _from, state)
      when not is_map_key(state.players, user_id) and not is_map_key(state.spectators, user_id),
      do: {:reply, {:error, :not_in_lobby}, state}

  def handle_call({:start_battle, _user_id}, _from, state)
      when state.current_battle != nil,
      do: {:reply, {:error, :battle_already_started}, state}

  def handle_call({:start_battle, _user_id}, _from, state) do
    with autohost_id when autohost_id != nil <- Autohost.find_autohost(),
         {:ok, {battle_id, battle_pid} = battle_data, host_data} <-
           TachyonBattle.start_battle(
             autohost_id,
             gen_start_script(state)
           ) do
      start_data = %{
        ips: host_data.ips,
        port: host_data.port,
        engine: %{version: state.engine_version},
        game: %{springName: state.game_version},
        map: %{springName: state.map_name}
      }

      for {p_id, p} <- Enum.concat(state.players, state.spectators),
          is_map_key(p, :password),
          do: Player.lobby_battle_start(p_id, battle_data, start_data, p.password)

      now = DateTime.utc_now()

      state =
        %{state | current_battle: %{id: battle_id, started_at: now}}
        |> Map.update!(:monitors, &MC.monitor(&1, battle_pid, :current_battle))

      broadcast_update({:update, nil, %{current_battle: state.current_battle}}, state)
      TachyonLobby.List.update_lobby(state.id, %{current_battle: %{started_at: now}})

      {:reply, :ok, state}
    else
      nil ->
        Logger.warning("No autohost available to start lobby battle")
        {:reply, {:error, :no_autohost}, state}

      {:error, reason} ->
        Logger.error("Cannot start lobby battle: #{inspect(reason)}")
        {:reply, {:error, reason}, state}
    end
  end

  def handle_call(:get_start_script, _from, state), do: {:reply, gen_start_script(state), state}

  @impl true
  def handle_info({:DOWN, ref, :process, _obj, reason}, state) do
    val = MC.get_val(state.monitors, ref)
    state = Map.update!(state, :monitors, &MC.demonitor_by_val(&1, val))

    state =
      case val do
        {:user, user_id} ->
          Logger.debug("user #{user_id} disappeared from the lobby because #{inspect(reason)}")

          cond do
            is_map_key(state.players, user_id) ->
              remove_player_from_lobby(user_id, state)

            is_map_key(state.spectators, user_id) ->
              remove_spectator_from_lobby(user_id, state)
          end

        :current_battle ->
          state = Map.put(state, :current_battle, nil)
          broadcast_update({:update, nil, %{current_battle: nil}}, state)
          TachyonLobby.List.update_lobby(state.id, %{current_battle: nil})
          state

        nil ->
          state
      end

    if Enum.empty?(state.players) and Enum.empty?(state.spectators) do
      {:noreply, state, {:continue, :empty}}
    else
      {:noreply, state}
    end
  end

  @impl true
  def handle_continue(:empty, state) do
    Logger.info("Lobby shutting down because empty")
    {:stop, {:shutdown, :empty}, state}
  end

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
        {p_id, %{team: p.team}}
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

  @spec new_state_from_events([event()], state()) :: state()
  defp new_state_from_events(events, state),
    do: Enum.reduce(events, state, &new_state_from_event/2)

  @spec new_state_from_event(event(), state()) :: state()
  defp new_state_from_event({:move_player, p_id, team}, state),
    do: put_in(state.players[p_id].team, team)

  defp new_state_from_event({:remove_player_from_lobby, p_id}, state) do
    state
    |> Map.update!(:players, &Map.delete(&1, p_id))
    |> Map.update!(:monitors, &MC.demonitor_by_val(&1, {:user, p_id}))
  end

  defp new_state_from_event({:remove_spec_from_lobby, s_id}, state) do
    state
    |> Map.update!(:spectators, &Map.delete(&1, s_id))
    |> Map.update!(:monitors, &MC.demonitor_by_val(&1, {:user, s_id}))
  end

  defp new_state_from_event({:move_spec_to_player, p_id, player_data}, state) do
    player =
      Map.merge(state.spectators[p_id], player_data)
      |> Map.delete(:join_queue_position)

    state
    |> Map.update!(:spectators, &Map.delete(&1, p_id))
    |> put_in([:players, p_id], player)
  end

  defp new_state_from_event({:move_player_to_spec, p_id, spec_data}, state) do
    spec =
      Map.merge(state.players[p_id], spec_data)
      |> Map.delete(:team)

    state
    |> Map.update!(:players, &Map.delete(&1, p_id))
    |> put_in([:spectators, p_id], spec)
  end

  defp new_state_from_event({:update_lobby_name, new_name}, state),
    do: Map.replace!(state, :name, new_name)

  defp new_state_from_event({:update_map_name, new_name}, state),
    do: Map.replace!(state, :map_name, new_name)

  defp new_state_from_event({:update_ally_team_config, new_config}, state),
    do: Map.replace!(state, :ally_team_config, new_config)

  # avoid sending a useless lobby list update when the last member of the lobby
  # just left. The caller of this function will detect the lobby is empty and
  # terminate the process, which will trigger the final lobby list update for
  # this lobby
  @spec broadcast_updates([event()], state()) :: state()
  defp broadcast_updates(_events, state)
       when map_size(state.players) == 0 and map_size(state.spectators) == 0,
       do: state

  defp broadcast_updates(events, state) do
    change_map =
      Enum.reduce(events, %{}, &update_change_from_event/2)

    broadcast_update({:update, nil, change_map}, state)
    state
  end

  defp update_change_from_event({:move_player, p_id, team}, change_map) do
    change_map
    |> Map.put_new(:players, %{})
    |> Map.update!(:players, fn players ->
      players |> Map.put_new(p_id, %{}) |> put_in([p_id, :team], team)
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

  defp update_change_from_event({:update_lobby_name, new_name}, change_map),
    do: Map.put(change_map, :name, new_name)

  defp update_change_from_event({:update_map_name, new_name}, change_map),
    do: Map.put(change_map, :map_name, new_name)

  defp update_change_from_event({:update_ally_team_config, new_config}, change_map),
    do: Map.put(change_map, :ally_team_config, new_config)

  defp broadcast_list_updates(_events, _starting_state, final_state)
       when map_size(final_state.players) == 0 and map_size(final_state.spectators) == 0,
       do: final_state

  defp broadcast_list_updates(events, _starting_state, final_state) do
    change_map =
      Enum.reduce(events, %{}, fn ev, change_map ->
        case ev do
          {:update_lobby_name, new_name} ->
            Map.put(change_map, :name, new_name)

          {:update_map_name, new_name} ->
            Map.put(change_map, :map_name, new_name)

          {:update_ally_team_config, new_config} ->
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

    events = remove_players_from_lobby([user_id | bot_ids_to_remove], state)
    state = new_state_from_events(events, state)
    {final_state, fill_events} = fill_players_from_join_queue(state)

    broadcast_updates(events ++ fill_events, final_state)
    broadcast_player_count_change(final_state)
  end

  @spec remove_spectator_from_lobby(T.userid(), state()) :: state()
  defp remove_spectator_from_lobby(user_id, state) do
    bot_ids_to_remove =
      Enum.filter(state.players, fn {_bot_id, b} -> Map.get(b, :host_user_id) == user_id end)
      |> Enum.map(&elem(&1, 0))

    events = remove_players_from_lobby(bot_ids_to_remove, state)
    events = [{:remove_spec_from_lobby, user_id} | events]

    state = new_state_from_events(events, state)
    {final_state, fill_events} = fill_players_from_join_queue(state)

    broadcast_updates(events ++ fill_events, final_state)
    broadcast_player_count_change(final_state)
  end

  # pure function that remove the given user from the players and adjust
  # all ally teams and teams to account for that so that there is no gap
  # in teams and ally teams.
  # for example, if an ally team looks like [p1, p2, p3] and p2 leaves, then
  # p3 will get adjusted so that its team is {0,1,0} leading to [p1, p3]
  # because this function is called in different contexts where what happens
  # to the removed player can change, the events returned do not include anything
  # related to the given player.
  # It is the responsability of the caller to add the correct event, which
  # can be remove from lobby, move to a different team, or become a spectator
  @spec do_remove_player(T.userid(), %{player_id() => player() | bot()}) :: [event()]
  # {%{player_id() => player() | bot()}, %{player_id() => %{team: team} | nil}}
  defp do_remove_player(user_id, players) do
    {%{team: {at_idx, t_idx, p_idx}}, players} =
      Map.pop!(players, user_id)

    # reorg the other players to keep the team indices consecutive
    # ally team won't change
    changes =
      Enum.reduce(players, [], fn {p_id, p}, player_changes ->
        {x, y, z} = p.team

        cond do
          x == at_idx && y >= t_idx && p_idx == 0 ->
            # p_idx == 0 means the player removed was the last one on their team
            # so its team can be "removed", and all teams with a higher index should
            # be moved back by 1
            team = {x, y - 1, z}

            [{:move_player, p_id, team} | player_changes]

          x == at_idx && y >= t_idx && z >= p_idx ->
            # similar there, but we only shuffle the players in the same team (archons)
            team = {x, y, z - 1}

            [{:move_player, p_id, team} | player_changes]

          true ->
            player_changes
        end
      end)

    changes
  end

  # remove the given players from lobby completely
  # it has to compute the intermediate states that will be thrown away
  # so it's not optimal on this side, maybe revisit that later if lobbies
  # prove to eat too much cpu (I highly doubt it will be the case)
  @spec remove_players_from_lobby([T.userid()], state()) :: [event()]
  defp remove_players_from_lobby(player_ids, state) do
    {_, events} =
      Enum.reduce(player_ids, {state, []}, fn player_id, {state, events} ->
        new_events = do_remove_player(player_id, state.players)
        new_events = [{:remove_player_from_lobby, player_id} | new_events]
        new_state = new_state_from_events(new_events, state)
        {new_state, events ++ new_events}
      end)

    events
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
              {id, %{team: team}}
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
        state = new_state_from_event(event, state)
        fill_players_from_join_queue(state, [event | events])
    end
  end

  defp gen_password(), do: :crypto.strong_rand_bytes(16) |> Base.encode16()

  # in tests, some user ids are string
  defp bot_id?(id) when is_integer(id), do: false
  defp bot_id?(id), do: String.starts_with?(id, "bot")

  @spec gen_start_script(state()) :: TachyonBattle.start_script()
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
                  userId: to_string(player.id),
                  name: player.name,
                  password: player.password
                }
              end

            bots =
              for bot <- bots do
                %{
                  hostUserId: to_string(bot.host_user_id),
                  name: Map.get(bot, :name),
                  aiShortName: bot.short_name,
                  aiVersion: Map.get(bot, :version),
                  aiOptions: bot.options
                }
                |> Enum.reject(fn {_, v} -> v == nil || v == %{} end)
                |> Map.new()
              end

            %{players: players, bots: bots} |> Enum.reject(&Enum.empty?(elem(&1, 1))) |> Map.new()
          end

        %{teams: teams, startBox: at_config.start_box}
      end

    %{
      engineVersion: state.engine_version,
      gameName: state.game_version,
      mapName: state.map_name,
      startPosType: :ingame,
      allyTeams: ally_teams,
      spectators:
        Enum.map(state.spectators, fn {_s_id, s} ->
          %{userId: to_string(s.id), name: s.name, password: s.password}
        end)
    }
  end

  @spec update_property(atom(), term(), state()) :: {:ok, [event()]} | {:error, String.t()}
  defp update_property(:name, new_name, _state) do
    # we can expand lobby name validation later
    if new_name == "" do
      {:error, "name must not be empty"}
    end

    {:ok, [{:update_lobby_name, new_name}]}
  end

  defp update_property(:map_name, new_name, _state),
    do: {:ok, [{:update_map_name, new_name}]}

  defp update_property(:ally_team_config, new_config, state) do
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
    remove_events = [{:update_ally_team_config, new_config} | spec_events ++ bot_events]

    state = new_state_from_events(remove_events, state)

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

  defp update_property(prop, _, _), do: {:error, "update #{prop} is not supported"}

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
