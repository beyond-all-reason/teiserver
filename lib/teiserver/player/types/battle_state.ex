defmodule Teiserver.Player.Types.BattleState do
  @moduledoc """
  data about the battle the player is in
  """
  alias Teiserver.TachyonBattle

  @enforce_keys [:id, :username, :password, :ip, :port, :engine, :game, :map]
  defstruct [:id, :username, :password, :ip, :port, :engine, :game, :map]

  @type t :: %__MODULE__{
          id: TachyonBattle.id(),
          username: String.t(),
          password: String.t(),
          ip: String.t(),
          port: integer(),
          engine: %{version: String.t()},
          game: %{spring_name: String.t()},
          map: %{spring_name: String.t()}
        }
end
