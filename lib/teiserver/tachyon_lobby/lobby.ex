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
          current_battle:
            nil
            | %{
                id: Teiserver.TachyonBattle.id(),
                started_at: DateTime.t()
              }
        }

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

  @typep state :: %{
           id: id(),
           monitors: MC.t(),
           name: String.t(),
           map_name: String.t(),
           game_version: String.t(),
           engine_version: String.t(),
           ally_team_config: ally_team_config(),
           # used to track the players in the lobby.
           players: %{T.userid() => player()},
           spectators: %{T.userid() => spectator()},
           current_battle:
             nil
             | %{
                 id: Teiserver.TachyonBattle.id(),
                 started_at: DateTime.t()
               }
         }

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
    case remove_player(user_id, state) do
      state when map_size(state.players) > 0 or map_size(state.spectators) > 0 ->
        {:reply, :ok, state}

      state ->
        {:reply, :ok, state, {:continue, :empty}}
    end
  end

  def handle_call({:leave, user_id}, _from, state) when is_map_key(state.spectators, user_id) do
    state = remove_spectator(user_id, state)

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

    team_count =
      Enum.filter(state.players, fn {_, %{team: {at, _, _}}} -> at == ally_team end)
      |> Enum.count()

    already_there? =
      case state.players[user_id] do
        nil -> false
        %{team: {at, _, _}} -> at == ally_team
      end

    cond do
      already_there? ->
        # TODO: broadcast this update
        {:reply, {:ok, get_details_from_state(state)}, state}

      team_count >= ally_team_capacity ->
        {:reply, {:error, :ally_team_full}, state}

      true ->
        # we guarantee that teams are consecutive in the ally team (without gap)
        # so we can use the team_count as the index for the new team in the ally team
        team = {ally_team, team_count, 0}

        case {state.players[user_id], state.spectators[user_id]} do
          {_player, nil} ->
            # we're moving a player from a different ally team
            changes = [{user_id, team} | do_remove_player(user_id, state.players)]

            change_map =
              for({user_id, team} <- changes, do: {user_id, %{team: team}})
              |> Enum.into(%{})

            broadcast_update({:update, nil, %{players: change_map}}, state)

            updated_players =
              Enum.reduce(changes, state.players, fn {p_id, team}, players ->
                put_in(players, [p_id, :team], team)
              end)

            state = Map.replace!(state, :players, updated_players)
            {:reply, {:ok, get_details_from_state(state)}, state}

          {nil, s} ->
            # Adding a spec into an ally team. The way we construct the team
            # means it doesn't require any reshuffling of existing players
            player = s |> Map.delete(:join_queue_position) |> Map.put(:team, team)

            state =
              state
              |> Map.update!(:spectators, &Map.delete(&1, user_id))
              |> Map.update!(:players, &Map.put(&1, user_id, player))

            update = %{
              players: %{user_id => %{team: team}},
              spectators: %{user_id => nil}
            }

            TachyonLobby.List.update_lobby(state.id, %{player_count: map_size(state.players)})
            broadcast_update({:update, nil, update}, state)

            {:reply, {:ok, get_details_from_state(state)}, state}
        end
    end
  end

  def handle_call({:spectate, user_id}, _from, state)
      when not is_map_key(state.players, user_id) and not is_map_key(state.spectators, user_id),
      do: {:reply, {:error, :not_in_lobby}, state}

  def handle_call({:spectate, user_id}, _from, state)
      when is_map_key(state.spectators, user_id) do
    {:reply, :ok, state}
  end

  def handle_call({:spectate, user_id}, _from, state) when is_map_key(state.players, user_id) do
    changes = do_remove_player(user_id, state.players)

    {spec, updated_players} =
      Enum.reduce(changes, state.players, fn {p_id, team}, ps ->
        put_in(ps, [p_id, :team], team)
      end)
      |> Map.pop!(user_id)

    spec = spec |> Map.delete(:team) |> Map.put(:join_queue_position, nil)

    state =
      state
      |> Map.put(:players, updated_players)
      |> put_in([:spectators, user_id], spec)

    player_changes =
      for({u_id, team} <- changes, do: {u_id, %{team: team}}, into: %{})
      |> Map.put(user_id, nil)

    {state, new_player_id} = add_player_from_join_queue(state)

    player_changes =
      if new_player_id == nil,
        do: player_changes,
        else: Map.put(player_changes, new_player_id, %{team: state.players[new_player_id].team})

    spec_changes = %{user_id => %{join_queue_position: nil}}

    spec_changes =
      if new_player_id == nil,
        do: spec_changes,
        else: Map.put(spec_changes, new_player_id, nil)

    change_map = %{players: player_changes, spectators: spec_changes}
    broadcast_update({:update, nil, change_map}, state)
    {:reply, :ok, state}
  end

  def handle_call({:join_queue, user_id}, _from, state)
      when not is_map_key(state.players, user_id) and not is_map_key(state.spectators, user_id),
      do: {:reply, {:error, :not_in_lobby}, state}

  def handle_call({:join_queue, user_id}, _from, state) when is_map_key(state.players, user_id),
    do: {:reply, :ok, state}

  def handle_call({:join_queue, user_id}, _from, state) do
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
          update = %{spectators: %{user_id => nil}, players: %{user_id => %{team: team}}}

          player =
            state.spectators[user_id]
            |> Map.delete(:join_queue_position)
            |> Map.put(:team, team)

          state =
            state
            |> put_in([:players, user_id], player)
            |> Map.update!(:spectators, &Map.delete(&1, user_id))

          broadcast_update({:update, nil, update}, state)
      end

    {:reply, :ok, state}
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
              remove_player(user_id, state)

            is_map_key(state.spectators, user_id) ->
              remove_spectator(user_id, state)
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
    players =
      Enum.map(state.players, fn {p_id, p} ->
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
  end

  # this function isn't too efficient, but it's never going to be run on
  # massive inputs since the engine cannot support more than 254 players anyway
  @spec find_team(ally_team_config(), %{T.userid() => player()}) :: team() | nil
  defp find_team(ally_team_config, players) do
    # find the least full ally team
    ally_team =
      for {at, at_idx} <- Enum.with_index(ally_team_config) do
        total_capacity = Enum.sum_by(at.teams, fn t -> t.max_players end)

        players_in_ally_team =
          Enum.filter(players, fn {_, %{team: {x, _, _}}} -> x == at_idx end)
          |> Enum.count()

        capacity = total_capacity - players_in_ally_team
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

  defp broadcast_update({:update, user_id, updates}, state) do
    events = [%{event: :updated, updates: updates}]
    broadcast_to_members(state, user_id, {:lobby, state.id, {:updated, events}})
  end

  defp broadcast_to_members(state, sender_id, message) do
    for {p_id, p} <- state.players, p_id != sender_id do
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
          {s.join_queue_position, {id, s}}

        true ->
          acc
      end
    end)
    |> elem(1)
  end

  @spec remove_player(T.userid(), state()) :: state()
  defp remove_player(user_id, state) do
    changes = do_remove_player(user_id, state.players)

    updated_players =
      Enum.reduce(changes, state.players, fn {p_id, team}, ps ->
        put_in(ps, [p_id, :team], team)
      end)
      |> Map.delete(user_id)

    state =
      Map.update!(state, :monitors, &MC.demonitor_by_val(&1, {:user, user_id}))
      |> Map.put(:players, updated_players)

    {state, new_player_id} = add_player_from_join_queue(state)

    # avoid sending a useless lobby list update when the last member of the lobby
    # just left. The caller of this function will detect the lobby is empty and
    # terminate the process, which will trigger the final lobby list update for
    # this lobby
    if map_size(state.players) > 0 || map_size(state.spectators) > 0 do
      TachyonLobby.List.update_lobby(state.id, %{player_count: map_size(state.players)})

      updates =
        changes
        |> Enum.map(fn {u_id, team} -> {u_id, %{team: team}} end)
        |> Map.new()
        |> Map.put(user_id, nil)
        |> then(fn m ->
          if new_player_id == nil,
            do: m,
            else: Map.put(m, new_player_id, %{team: state.players[new_player_id].team})
        end)

      change_map = %{players: updates}

      change_map =
        if new_player_id == nil,
          do: change_map,
          else: Map.put(change_map, :spectators, %{new_player_id => nil})

      broadcast_update({:update, user_id, change_map}, state)
    end

    state
  end

  @spec remove_spectator(T.userid(), state()) :: state()
  defp remove_spectator(user_id, state) do
    state =
      Map.update!(state, :spectators, &Map.delete(&1, user_id))
      |> Map.update!(:monitors, &MC.demonitor_by_val(&1, {:user, user_id}))

    broadcast_update({:update, user_id, %{spectators: %{user_id => nil}}}, state)
    state
  end

  # pure function that remove the given user from the players and adjust
  # all ally team and team configuration to account for that
  # returns the list of {player_id, new_team} that were modified in the process
  @spec do_remove_player(T.userid(), %{T.userid() => player()}) :: [{T.userid(), team()}]
  defp do_remove_player(user_id, players) do
    {%{team: {at_idx, t_idx, p_idx}}, players} =
      Map.pop!(players, user_id)

    # reorg the other players to keep the team indices consecutive
    # ally team won't change
    Enum.reduce(players, [], fn {p_id, p}, player_changes ->
      {x, y, z} = p.team

      cond do
        x == at_idx && y >= t_idx && p_idx == 0 ->
          # p_idx == 0 means the player removed was the last one on their team
          # so its team can be "removed", and all teams with a higher index should
          # be moved back by 1
          team = {x, y - 1, z}

          [{p_id, team} | player_changes]

        x == at_idx && y >= t_idx && z >= p_idx ->
          # similar there, but we only shuffle the players in the same team (archons)
          team = {x, y, z - 1}

          [{p_id, team} | player_changes]

        true ->
          player_changes
      end
    end)
  end

  # Add the first player from the join queue to the player list and returns the
  # updated state alongside the player id that was added
  # Assumes there is a spot available in an ally team
  @spec add_player_from_join_queue(state()) :: {state(), T.userid() | nil}
  defp add_player_from_join_queue(state) do
    player_to_add =
      case get_first_player_in_join_queue(state.spectators) do
        nil ->
          nil

        {id, p} ->
          team = find_team(state.ally_team_config, state.players)
          p = p |> Map.put(:team, team) |> Map.delete(:join_queue_position)
          {id, p}
      end

    case player_to_add do
      nil ->
        {state, nil}

      {id, p} ->
        state =
          put_in(state.players[id], p)
          |> Map.update!(:spectators, &Map.delete(&1, id))

        {state, id}
    end
  end

  defp gen_password(), do: :crypto.strong_rand_bytes(16) |> Base.encode16()

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
            players =
              for player <- team do
                %{
                  userId: to_string(player.id),
                  name: player.name,
                  password: player.password
                }
              end

            %{players: players}
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
end
