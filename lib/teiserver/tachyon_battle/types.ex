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
          engineVersion: String.t(),
          gameName: String.t(),
          mapName: String.t(),
          startPosType: :fixed | :random | :ingame | :beforegame,
          allyTeams: [ally_team(), ...]
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
