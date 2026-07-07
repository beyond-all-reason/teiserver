defmodule Teiserver.TachyonLobby.Types.SpectatorDetails do
  @moduledoc """
  Public version of a spectator in a lobby.
  """

  @enforce_keys [:id]
  defstruct [:id, :join_queue_position]

  @type t() :: %__MODULE__{
          id: Teiserver.Account.User.id(),
          join_queue_position: number() | nil
        }
end
