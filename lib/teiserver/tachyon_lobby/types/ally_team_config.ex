defmodule Teiserver.TachyonLobby.Types.AllyTeamConfig do
  @moduledoc """
  Ally team configuration for tachyon lobbies
  """

  alias Teiserver.Asset

  # start box are optional, if none given, engine allow spawing anywhere on
  # the map. It can also be controlled game side through modoption, that's
  # how polygon start boxes work
  @enforce_keys [:max_teams, :teams]
  defstruct [:max_teams, :teams, :start_box]

  @type t() :: %__MODULE__{
          max_teams: pos_integer(),
          teams: [%{max_players: pos_integer()}],
          start_box: Asset.startbox()
        }
end
