defmodule Teiserver.TachyonLobby.Lobby do
  @moduledoc """
  Represent a single lobby
  """

  require Logger
  use GenServer, restart: :transient

  alias Teiserver.Asset
  alias Teiserver.Data.Types, as: T
  alias Teiserver.TachyonLobby
  alias Teiserver.Helpers.MonitorCollection, as: MC

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
  These represent the indices respectively into
  {ally team index, team index, player index}
  since we don't really support "archon mode" though, the player index
  is likely always going to be 0.
  For example, a player in the first ally team, in the second spot
  would have: {0, 1, 0}
  """
  @type team :: {non_neg_integer(), non_neg_integer(), non_neg_integer()}

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
              id: T.userid(),
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

  @typedoc """
  the parameters required to create a new lobby.
  It's enough data to generate the initial lobby internal state, which in
  turn can be used to start a battle
  """
  @type start_params :: %{
          creator_user_id: T.userid(),
          creator_pid: pid(),
          name: String.t(),
          map_name: String.t(),
          ally_team_config: [
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
        }

  @typep player :: %{
           # These represent the indices respectively into
           # {ally team index, team index, player index}
           # since we don't really support "archon mode" though, the player index
           # is likely always going to be 0.
           # For example, a player in the first ally team, in the second spot
           # would have: {0, 1, 0}
           team: {non_neg_integer(), non_neg_integer(), non_neg_integer()}
         }

  @typep state :: %{
           id: id(),
           monitors: MC.t(),
           name: String.t(),
           map_name: String.t(),
           game_version: String.t(),
           engine_version: String.t(),
           ally_team_config: [
             %{
               max_teams: pos_integer(),
               start_box: Asset.startbox(),
               teams: [
                 %{
                   max_players: pos_integer()
                 }
               ]
             }
           ],
           # used to track the players in the lobby.
           players: %{T.userid() => player()}
         }

  @spec gen_id() :: id()
  def gen_id(), do: UUID.uuid4()

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

  @impl true
  @spec init({id(), start_params()}) :: {:ok, state()}
  def init({id, start_params}) do
    Logger.metadata(actor_type: :lobby, actor_id: id)

    monitors =
      MC.new() |> MC.monitor(start_params.creator_pid, {:user, start_params.creator_user_id})

    state = %{
      id: id,
      monitors: monitors,
      name: start_params.name,
      map_name: start_params.map_name,
      game_version: "BAR-27755-75d0172",
      engine_version: "2025.04.08",
      ally_team_config: start_params.ally_team_config,
      players: %{
        start_params.creator_user_id => %{
          user_id: start_params.creator_user_id,
          team: {0, 0, 0}
        }
      }
    }

    TachyonLobby.List.register_lobby(self(), id, %{
      name: state.name,
      player_count: map_size(state.players),
      max_player_count:
        Enum.sum(
          for at <- state.ally_team_config, team <- at.teams do
            at.max_teams * team.max_players
          end
        ),
      map_name: state.map_name,
      engine_version: state.engine_version,
      game_version: state.game_version
    })

    {:ok, state}
  end

  @impl true
  def handle_call(:get_details, _from, state) do
    details =
      Map.take(state, [:id, :name, :map_name, :game_version, :engine_version, :ally_team_config])
      |> Map.put(
        :members,
        for {p_id, p} <- state.players, into: %{} do
          {p_id, Map.put(p, :type, :player)}
        end
      )

    {:reply, {:ok, details}, state}
  end

  @impl true
  def handle_info({:DOWN, ref, :process, _obj, _reason}, state) do
    val = MC.get_val(state.monitors, ref)
    state = Map.update!(state, :monitors, &MC.demonitor_by_val(&1, val))

    state =
      case val do
        {:user, user_id} ->
          state = %{state | players: Map.delete(state.players, user_id)}
          TachyonLobby.List.update_lobby(state.id, %{player_count: map_size(state.players)})
          state
      end

    if Enum.empty?(state.players) do
      {:stop, {:shutdown, :empty}, state}
    else
      {:noreply, state}
    end
  end

  @spec via_tuple(id()) :: GenServer.name()
  defp via_tuple(lobby_id) do
    TachyonLobby.Registry.via_tuple(lobby_id)
  end
end
