defmodule Teiserver.TachyonLobby.Types.Player do
  @moduledoc """
  Internal representation of a player in a lobby.
  Holds all data required to start a game
  """
  alias Teiserver.TachyonLobby.Types.Types, as: LT

  @enforce_keys [:id, :name, :password, :team, :ready?, :asset_status]
  defstruct [:id, :name, :password, :pid, :team, :ready?, :asset_status]

  @type t() :: %__MODULE__{
          id: Teiserver.Account.User.id(),
          name: String.t(),
          # used to generate the start script, and then will be sent to the
          # player so they can join the battle
          password: String.t(),
          # pid can be nil when restoring state from snapshot until
          # the session rejoins the lobby
          pid: pid() | nil,
          team: LT.team(),
          ready?: boolean(),
          asset_status: LT.asset_status()
        }
end
