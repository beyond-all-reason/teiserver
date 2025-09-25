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
          members: %{
            T.userid() => %{
              type: :player,
              team: team()
            }
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
  def join(lobby_id, join_data, pid) do
    GenServer.call(via_tuple(lobby_id), {:join, join_data, pid})
  catch
    :exit, {:noproc, _} -> {:error, :invalid_lobby}
  end

  @spec leave(id(), T.userid()) :: :ok | {:error, reason :: term()}
  def leave(lobby_id, user_id) do
    GenServer.call(via_tuple(lobby_id), {:leave, user_id})
  catch
    :exit, {:noproc, _} -> {:error, :invalid_lobby}
  end

  @spec start_battle(id(), T.userid()) :: :ok | {:error, reason :: term()}
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
      when is_map_key(join_data.id, state.players) do
    {:reply, {:ok, self(), get_details_from_state(state)}, state}
  end

  def handle_call({:join, join_data, pid}, _from, state) do
    # find the least full team
    team = find_team(state.ally_team_config, Map.values(state.players))
    user_id = join_data.id

    case team do
      nil ->
        {:reply, {:error, :lobby_full}, state}

      team ->
        state =
          put_in(state, [:players, user_id], %{
            id: user_id,
            name: join_data.name,
            password: gen_password(),
            pid: pid,
            team: team
          })
          |> Map.update!(:monitors, &MC.monitor(&1, pid, {:user, user_id}))

        broadcast_update({:add_player, user_id, team, state})

        {:reply, {:ok, self(), get_details_from_state(state)}, state}
    end
  end

  def handle_call({:leave, user_id}, _from, state) do
    case remove_player(user_id, state) do
      {:ok, state} when map_size(state.players) > 0 -> {:reply, :ok, state}
      {:ok, state} -> {:reply, :ok, state, {:continue, :empty}}
      {:error, _} = err -> {:reply, err, state}
    end
  end

  def handle_call({:start_battle, user_id}, _from, state)
      when not is_map_key(state.players, user_id),
      do: {:reply, {:error, :not_a_player_in_lobby}, state}

  def handle_call({:start_battle, _user_id}, _from, state) do
    with autohost_id when autohost_id != nil <- Autohost.find_autohost(),
         {:ok, {battle_id, _} = battle_data, host_data} <-
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

      for {p_id, p} <- state.players,
          do: Player.lobby_battle_start(p_id, battle_data, start_data, p.password)

      now = DateTime.utc_now()
      state = %{state | current_battle: %{id: battle_id, started_at: now}}
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

  @impl true
  def handle_info({:DOWN, ref, :process, _obj, reason}, state) do
    val = MC.get_val(state.monitors, ref)
    state = Map.update!(state, :monitors, &MC.demonitor_by_val(&1, val))

    state =
      case val do
        {:user, user_id} ->
          Logger.debug("user #{user_id} disappeared from the lobby because #{inspect(reason)}")

          case remove_player(user_id, state) do
            {:ok, state} -> state
            _ -> state
          end
      end

    if Enum.empty?(state.players) do
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

  defp get_details_from_state(state) do
    Map.take(state, [
      :id,
      :name,
      :map_name,
      :game_version,
      :engine_version,
      :ally_team_config
    ])
    |> Map.put(
      :members,
      Enum.map(state.players, fn {p_id, p} ->
        {p_id, %{type: :player, team: p.team}}
      end)
      |> Enum.into(%{})
    )
  end

  defp broadcast_update({:add_player, user_id, team, state}) do
    TachyonLobby.List.update_lobby(state.id, %{player_count: map_size(state.players)})

    for {p_id, p} <- state.players, p_id != user_id do
      send(
        p.pid,
        {:lobby, state.id, {:updated, [%{event: :add_player, id: user_id, team: team}]}}
      )
    end

    :ok
  end

  defp broadcast_update({:remove_player, user_id, player_changes, state}) do
    TachyonLobby.List.update_lobby(state.id, %{player_count: map_size(state.players)})

    # TODO: a potential optimisation is to coalesce all these events into one
    # all the :change_player can be merged into one single map change
    events =
      for {:player_moved, p_id, team} <- player_changes,
          do: %{event: :change_player, id: p_id, team: team}

    events = [%{event: :remove_player, id: user_id} | events]

    for {_p_id, p} <- state.players,
        do: send(p.pid, {:lobby, state.id, {:updated, events}})
  end

  # this function isn't too efficient, but it's never going to be run on
  # massive inputs since the engine cannot support more than 254 players anyway
  @spec find_team(ally_team_config(), [player()]) :: team() | nil
  defp find_team(ally_team_config, players) do
    # find the least full ally team
    ally_team =
      for {at, at_idx} <- Enum.with_index(ally_team_config) do
        total_capacity = Enum.sum_by(at.teams, fn t -> t.max_players end)

        players_in_ally_team =
          Enum.filter(players, fn %{team: {x, _, _}} -> x == at_idx end)
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
              Enum.filter(players, fn %{team: {x, y, _}} ->
                x == at_idx && y == t_idx
              end)
              |> Enum.count()

            capacity = t.max_players - player_count
            {capacity, t_idx, player_count}
          end
          |> Enum.filter(fn {c, _, _} -> c > 0 end)
          # guarantee not to raise an exception
          |> Enum.min()

        {at_idx, t_idx, p_idx}
    end
  end

  @spec remove_player(T.userid(), state()) :: {:ok, state()} | {:error, :not_in_lobby}
  defp remove_player(user_id, state) when not is_map_key(state.players, user_id),
    do: {:error, :not_in_lobby}

  defp remove_player(user_id, state) do
    {%{team: {at_idx, t_idx, p_idx}} = removed, players} =
      Map.pop!(state.players, user_id)

    # reorg the other players to keep the team indices consecutive
    # ally team won't change
    {player_changes, updated_players} =
      Enum.reduce(players, {[], %{}}, fn {p_id, p}, {player_changes, players} ->
        {x, y, z} = p.team

        cond do
          x == at_idx && y >= t_idx && p_idx == 0 ->
            # p_idx == 0 means the player removed was the last one on their team
            # so its team can be "removed", and all teams with a higher index should
            # be moved back by 1
            team = {x, y - 1, z}

            {[{:player_moved, p_id, team} | player_changes],
             Map.put(players, p_id, %{p | team: team})}

          x == at_idx && y >= t_idx && z >= p_idx ->
            # similar there, but we only shuffle the players in the same team (archons)
            team = {x, y, z - 1}

            {[{:player_moved, p_id, team} | player_changes],
             Map.put(players, p_id, %{p | team: team})}

          true ->
            {player_changes, Map.put(players, p_id, p)}
        end
      end)

    state =
      Map.update!(state, :monitors, &MC.demonitor_by_val(&1, removed.id))
      |> Map.put(:players, updated_players)

    if map_size(state.players) > 0,
      do: broadcast_update({:remove_player, user_id, player_changes, state})

    {:ok, state}
  end

  defp gen_password(), do: :crypto.strong_rand_bytes(16) |> Base.encode16()

  @spec gen_start_script(state()) :: TachyonBattle.start_script()
  defp gen_start_script(state) do
    sorted =
      Map.values(state.players)
      |> Enum.sort_by(& &1.team)
      |> Enum.group_by(&elem(&1.team, 0))

    ally_teams =
      for i <- 0..(map_size(sorted) - 1) do
        at = sorted[i]
        at_config = Enum.at(state.ally_team_config, i)

        teams = Enum.group_by(at, &elem(&1.team, 1))

        teams =
          for j <- 0..(map_size(teams) - 1) do
            ps = teams[j]

            players =
              for p <- ps do
                %{
                  userId: to_string(p.id),
                  name: p.name,
                  password: p.password
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
      allyTeams: ally_teams
    }
  end
end
