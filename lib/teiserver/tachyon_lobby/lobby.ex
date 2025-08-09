defmodule Teiserver.TachyonLobby.Lobby do
  @moduledoc """
  Represent a single lobby
  """

  require Logger
  use GenServer, restart: :transient

  alias Teiserver.Asset
  alias Teiserver.Data.Types, as: T
  alias Teiserver.TachyonLobby

  @type id :: String.t()

  @typedoc """
  the parameters required to create a new lobby.
  It's enough data to generate the initial lobby internal state, which in
  turn can be used to start a battle
  """
  @type start_params :: %{
          creator_user_id: T.userid(),
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

  @spec start_link({id(), start_params()}) :: GenServer.on_start()
  def start_link({id, _start_params} = args) do
    GenServer.start_link(__MODULE__, args, name: via_tuple(id))
  end

  @impl true
  @spec init({id(), start_params()}) :: {:ok, state()}
  def init({id, start_params}) do
    Logger.metadata(actor_type: :lobby, actor_id: id)

    state = %{
      id: id,
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

    {:ok, state}
  end

  @spec via_tuple(id()) :: GenServer.name()
  defp via_tuple(lobby_id) do
    TachyonLobby.Registry.via_tuple(lobby_id)
  end
end
