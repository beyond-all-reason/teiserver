defmodule Teiserver.TestData do
  # Dummy module to create fake data until this is hooked up to
  # an actual data store
  alias Teiserver.User
  alias Teiserver.Battle

  def create_users do
    ConCache.insert_new(:lists, :users, [])
    [
      %{
        name: "Testuser1",
        country: "GB",
        userid: 1,
        lobbyid: "LuaLobby Chobby",
        friends: [],
        friend_requests: []
      },
      %{
        name: "Testuser2",
        country: "DE",
        userid: 2,
        lobbyid: "LuaLobby Chobby",
        friends: [],
        friend_requests: []
      },
      %{
        name: "Teifion",
        country: "DE",
        userid: 3,
        lobbyid: "LuaLobby Chobby",
        friends: ["Addas"],
        friend_requests: ["Link"]
      },
      %{
        name: "Addas",
        country: "DE",
        userid: 4,
        lobbyid: "LuaLobby Chobby",
        friends: ["Teifion"],
        friend_requests: []
      },
      %{
        name: "Link",
        country: "IR",
        userid: 5,
        lobbyid: "LuaLobby Chobby",
        friends: [],
        friend_requests: []
      },
    ]
    |> Enum.map(&User.add_user/1)
  end

  def create_battles do
    ConCache.insert_new(:lists, :battles, [])
    [
      %{
        id: 898,
        type: :normal,
        nattype: :none,
        founder: "Testuser1",
        ip: "127.8.0.1",
        port: "322",
        max_players: 16,
        passworded: false,
        rank: 0,
        locked: false,
        map_hash: 1794707373,
        engine_name: "spring",
        engine_version: "104.0.1-1714-g321b911",
        map_name: "BAR Glacier Pass 1.2",
        title: "USA -- 04",
        game_name: "Beyond All Reason",
        channel: "test-15367-6bfafcb",

        spectators: [],
        players: []
      }
    ]
    |> Enum.map(&Battle.add_battle/1)
  end
end