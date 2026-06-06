defmodule Teiserver.TachyonLobby.Types.PlayerDetails do
  @moduledoc """
  Public version of a player in a lobby. Subset of Types.Player
  """
  alias Teiserver.TachyonLobby.Types.Types, as: LT

  @enforce_keys [:id, :team, :ready?, :asset_status]
  defstruct [:id, :team, :ready?, :asset_status]

  @type t() :: %__MODULE__{
          id: Teiserver.Account.User.id(),
          team: LT.team(),
          ready?: boolean(),
          asset_status: LT.asset_status()
        }
end
