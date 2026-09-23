defmodule Teiserver.Player.Types.BattleState do
  @moduledoc """
  data about the battle the player is in
  """
  alias Teiserver.TachyonBattle

  @enforce_keys [:id, :match_id, :username, :password, :ips, :port, :engine, :game, :map]
  defstruct [:id, :match_id, :username, :password, :ips, :port, :engine, :game, :map]

  @type t :: %__MODULE__{
          id: TachyonBattle.id(),
          match_id: TachyonBattle.Types.match_id(),
          username: String.t(),
          password: String.t(),
          ips: [String.t()],
          port: integer(),
          engine: %{version: String.t()},
          game: %{spring_name: String.t()},
          map: %{spring_name: String.t()}
        }
end
