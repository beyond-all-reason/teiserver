defmodule Teiserver.TestData do
  @moduledoc """
  Dummy module to create fake data until this is hooked up to
  an actual data store
  """
  alias Teiserver.User
  alias Teiserver.Client
  alias Teiserver.Battle

  def create_users do
    ConCache.insert_new(:lists, :users, [])

    [
      %{
        # ID: 1
        name: "ChanServ",
        email: "ChanServ@teiserver.com",
        country: "GB",
        lobbyid: "LuaLobby Chobby",
        friends: [],
        friend_requests: [],
        ignored: [],
        rank: 1,
        bot: true,
        moderator: true
      },
      %{
        # ID: 2
        name: "[teh]cluster1[03]",
        email: "[teh]cluster1[03]@teiserver.com",
        country: "GB",
        lobbyid: "LuaLobby Chobby",
        friends: [],
        friend_requests: [],
        ignored: [],
        rank: 1,
        bot: true,
        moderator: false
      },
      %{
        name: "TestUser",
        email: "TestUser@teiserver.com",
        country: "US",
        lobbyid: "LuaLobby Chobby",
        friends: ["Friend1", "Friend2"],
        friend_requests: ["FriendRequest1"],
        ignored: ["Ignored1", "Ignored2"],
        rank: 1,
        bot: false,
        moderator: true
      },
      %{
        name: "TestUser2",
        email: "TestUser2@teiserver.com",
        country: "GB",
        lobbyid: "LuaLobby Chobby",
        friends: [],
        friend_requests: [],
        ignored: [],
        rank: 2,
        bot: false,
        moderator: false
      },
      %{
        name: "Teifion",
        email: "Teifion@teiserver.com",
        country: "GB",
        lobbyid: "LuaLobby Chobby",
        friends: ["Addas"],
        friend_requests: [],
        ignored: [],
        rank: 5,
        bot: false,
        moderator: false
      },
      %{
        name: "Addas",
        email: "Addas@teiserver.com",
        country: "DE",
        lobbyid: "LuaLobby Chobby",
        friends: ["Teifion"],
        friend_requests: [],
        ignored: [],
        rank: 4,
        bot: false,
        moderator: false
      },
      %{
        name: "Link",
        email: "Link@teiserver.com",
        country: "IE",
        lobbyid: "LuaLobby Chobby",
        friends: [],
        friend_requests: [],
        ignored: [],
        rank: 3,
        bot: false,
        moderator: false
      },
      %{
        name: "Chon",
        email: "Chon@teiserver.com",
        country: "IE",
        lobbyid: "LuaLobby Chobby",
        friends: [],
        friend_requests: [],
        rank: 2,
        bot: false,
        moderator: true
      }
    ]
    |> Enum.map(fn user ->
      Map.merge(%{
        password_hash: "X03MO1qnZdYdgyfeuILPmQ==",
        verified: true,
        verification_code: nil
      }, user)
    end)
    |> Enum.map(&User.create_user/1)
    |> Enum.map(&User.add_user/1)
  end

  def create_clients do
    [
      %{
        pid: nil,
        name: "[teh]cluster1[03]",
        protocol: Teiserver.Protocols.Spring,
        in_game: false,
        away: false,
        rank: 1,
        moderator: true,
        bot: true,
        battlestatus: 4_194_306,
        team_colour: 16_777_215,
        battle_id: 1,
        status: 16,
        userid: 2
      }
      # %{
      #   pid: nil,
      #   name: "Chon",
      #   protocol: Teiserver.Protocols.Spring,
      #   in_game: false,
      #   away: false,
      #   rank: 1,
      #   moderator: false,
      #   bot: true,
      #   battlestatus: 0,
      #   team_colour: 0,
      #   battle_id: nil,
      #   status: 16
      # }
    ]
    |> Enum.map(&Client.create/1)
    |> Enum.map(&Client.add_client/1)
  end

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
        title: "USA -- 04",
        game_name: "Beyond All Reason test-15367-6bfafcb",
        players: [2]
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
        title: "USA -- 03",
        game_name: "Beyond All Reason test-15367-6bfafcb",
        players: [2]
      }
    ]
    |> Enum.map(&Battle.create_battle/1)
    |> Enum.map(&Battle.add_battle/1)
  end
end
