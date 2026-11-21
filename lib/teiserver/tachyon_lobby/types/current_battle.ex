defmodule Teiserver.TachyonLobby.Types.CurrentBattle do
  @moduledoc """
  Internal representation of a battle attached to a lobby
  """

  alias Teiserver.Battle.Match
  alias Teiserver.TachyonBattle

  @enforce_keys [:id, :pid, :match_id, :started_at]
  defstruct [:id, :pid, :match_id, :started_at]

  @type t() :: %__MODULE__{
          id: TachyonBattle.id(),
          pid: pid(),
          match_id: Match.id(),
          started_at: DateTime.t()
        }
end
