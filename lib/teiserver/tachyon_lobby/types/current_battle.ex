defmodule Teiserver.TachyonLobby.Types.CurrentBattle do
  @moduledoc """
  Internal representation of a battle attached to a lobby
  """

  alias Teiserver.TachyonBattle

  @enforce_keys [:id, :pid, :started_at]
  defstruct [:id, :pid, :started_at]

  @type t() :: %__MODULE__{
          id: TachyonBattle.id(),
          pid: pid(),
          started_at: DateTime.t()
        }
end
