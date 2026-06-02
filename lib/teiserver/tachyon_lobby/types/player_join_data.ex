defmodule Teiserver.TachyonLobby.Types.PlayerJoinData do
  @moduledoc """
  Data required for a player to join a lobby. This allow lobbies to
  be agnostic of how players are represented in the system
  """

  @enforce_keys [:id, :name]
  defstruct [:id, :name]

  @type t() :: %__MODULE__{
          id: Teiserver.Account.User.id(),
          name: String.t()
        }
end
