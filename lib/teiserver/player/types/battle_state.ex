defmodule Teiserver.Player.Types.BattleState do
  @moduledoc """
  data about the battle the player is in
  """
  alias Teiserver.TachyonBattle

  @enforce_keys [:id]
  defstruct [:id]

  @type t :: %__MODULE__{
          id: TachyonBattle.id()
        }
end
