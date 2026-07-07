defmodule Teiserver.TachyonLobby.Types.Spectator do
  @moduledoc """
  Internal representation of a spectator in a lobby
  """

  @enforce_keys [:id]
  defstruct [:id, :name, :password, :pid, :join_queue_position]

  @type t() :: %__MODULE__{
          id: Teiserver.Account.User.id(),
          name: String.t(),
          # pid can be nil when restoring state from snapshot until
          # the session rejoins the lobby
          password: String.t(),
          pid: pid(),
          join_queue_position: number() | nil
        }
end
