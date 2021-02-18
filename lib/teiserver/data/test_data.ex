defmodule Teiserver.TestData do
  @moduledoc """
  Dummy module to create fake data until this is hooked up to
  an actual data store
  """
  alias Teiserver.Battle

  def create_battles do
    ConCache.insert_new(:lists, :battles, [])

    [
      %{
        type: :normal,
        nattype: :none,
        founder: 2,
        ip: "127.8.0.1",
        port: "322",
        max_players: 16,
        passworded: false,
        rank: 0,
        locked: false,
        map_hash: 1_683_043_765,
        hash_code: 1_683_043_765,
        engine_name: "spring",
        engine_version: "104.0.1-1714-g321b911",
        map_name: "Supreme_Crossing_V1",
        name: "USA -- 04",
        game_name: "Beyond All Reason test-15367-6bfafcb",
        players: []
      },
      %{
        type: :normal,
        nattype: :none,
        founder: 2,
        ip: "127.8.0.1",
        port: "322",
        max_players: 16,
        passworded: false,
        rank: 0,
        locked: false,
        map_hash: 733_360_208,
        hash_code: 733_360_208,
        engine_name: "spring",
        engine_version: "104.0.1-1714-g321b911",
        map_name: "Quicksilver Remake 1.24",
        name: "USA -- 03",
        game_name: "Beyond All Reason test-15367-6bfafcb",
        players: []
      }
    ]
    |> Enum.map(&Battle.create_battle/1)
    |> Enum.map(&Battle.add_battle/1)
  end
end
