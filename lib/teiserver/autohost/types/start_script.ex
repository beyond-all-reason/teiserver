defmodule Teiserver.Autohost.Types.StartScript do
  @moduledoc """
  Internal representation of the start script to be sent to autohost to
  start a battle
  """

  alias Teiserver.Autohost.Types, as: AT

  @enforce_keys [:engine_version, :game_name, :map_name, :start_pos_type, :ally_teams]
  defstruct [
    :engine_version,
    :game_name,
    :map_name,
    :start_pos_type,
    :ally_teams,
    game_options: %{},
    spectators: [],
    bots: []
  ]

  @type t() :: %__MODULE__{
          engine_version: String.t(),
          game_name: String.t(),
          map_name: String.t(),
          start_pos_type: :fixed | :random | :ingame | :beforegame,
          ally_teams: [ally_team(), ...],
          game_options: %{String.t() => String.t()},
          spectators: [AT.Player.t()],
          bots: [AT.Bot.t()]
        }

  @type ally_team :: %{
          teams: [team(), ...]
        }

  @type team :: %{
          players: [AT.Player.t()]
        }
end
