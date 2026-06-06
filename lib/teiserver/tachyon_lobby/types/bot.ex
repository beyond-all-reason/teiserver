defmodule Teiserver.TachyonLobby.Types.Bot do
  @moduledoc """
  A bot in a lobby. It always has a team (a bot cannot be a spectator)
  and is also tied to a player: their machine is used to run the AI
  """

  alias Teiserver.TachyonLobby.Types.Types, as: LT

  @enforce_keys [:id, :host_user_id, :team, :name]
  defstruct [:id, :host_user_id, :team, :name, :short_name, :version, :options]

  @type id() :: String.t()
  @type t() :: %__MODULE__{
          id: id(),
          host_user_id: Teiserver.Account.User.id(),
          team: LT.team(),
          name: String.t(),
          short_name: String.t() | nil,
          version: String.t() | nil,
          options: %{String.t() => String.t()}
        }
end
