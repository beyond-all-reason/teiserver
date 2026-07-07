defmodule Teiserver.TachyonLobby.Types.CurrentBattleDetails do
  @moduledoc """
  Public version of CurrentBattle
  """

  alias Teiserver.TachyonBattle

  @enforce_keys [:id, :started_at]
  defstruct [:id, :started_at]

  @type t() :: %__MODULE__{
          id: TachyonBattle.id(),
          started_at: DateTime.t()
        }
end
