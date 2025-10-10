defmodule Teiserver.TachyonBattle.Types do
  @moduledoc """
  for shared types across the tachyon battle modules when there is no clear
  module that should own them
  """

  @type id :: String.t()

  # unfortunately typespecs don't support merging maps, so this is a
  # redeclaration of Autohost.start_script(), but without the battle id
  # https://elixirforum.com/t/typespec-combining-maps/31416
  @type start_script :: %{
          required(:engineVersion) => String.t(),
          required(:gameName) => String.t(),
          required(:mapName) => String.t(),
          required(:startPosType) => :fixed | :random | :ingame | :beforegame,
          required(:allyTeams) => [ally_team(), ...],
          optional(:spectators) => [player()]
        }

  @type ally_team :: %{
          teams: [team(), ...]
        }

  @type team :: %{
          players: [player()]
        }

  @type player :: %{
          userId: String.t(),
          name: String.t(),
          password: String.t()
        }
end
