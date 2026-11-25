defmodule Teiserver.TachyonLobby.ListFiltersTest do
  alias Teiserver.Account
  alias Teiserver.AccountFixtures
  alias Teiserver.Party
  alias Teiserver.Player.SessionRegistry
  alias Teiserver.TachyonLobby.Types, as: LT
  alias Teiserver.TachyonLobby.Types.ListFilters

  use Teiserver.DataCase, async: false

  @moduletag :tachyon

  @lobby_id "lobby-id"

  setup do
    {:ok, user: AccountFixtures.user_fixture()}
  end

  describe "lobby filter matching" do
    test "empty filters match everything", ctx do
      assert ListFilters.filter(@lobby_id, lobby_overview(), %{}, ctx.user, nil)
    end

    test "map names", ctx do
      # map_name "Supreme That Glitters"
      assert ListFilters.filter(
               @lobby_id,
               lobby_overview(),
               %{map_names: MapSet.new(["Supreme That Glitters", "Altored"])},
               ctx.user,
               nil
             )

      refute ListFilters.filter(
               @lobby_id,
               lobby_overview(),
               %{map_names: MapSet.new(["Rosetta"])},
               ctx.user,
               nil
             )
    end

    test "player count, both bounds inclusive", ctx do
      # player_count 4
      lobby = lobby_overview()

      assert ListFilters.filter(@lobby_id, lobby, %{player_count: %{min: 4}}, ctx.user, nil)
      assert ListFilters.filter(@lobby_id, lobby, %{player_count: %{max: 4}}, ctx.user, nil)

      assert ListFilters.filter(
               @lobby_id,
               lobby,
               %{player_count: %{min: 2, max: 6}},
               ctx.user,
               nil
             )

      refute ListFilters.filter(@lobby_id, lobby, %{player_count: %{min: 5}}, ctx.user, nil)
      refute ListFilters.filter(@lobby_id, lobby, %{player_count: %{max: 3}}, ctx.user, nil)
    end

    test "ally teams, both bounds inclusive", ctx do
      # ally_team_count 2
      lobby = lobby_overview()

      assert ListFilters.filter(@lobby_id, lobby, %{ally_teams: %{min: 2, max: 2}}, ctx.user, nil)
      assert ListFilters.filter(@lobby_id, lobby, %{ally_teams: %{min: 1, max: 4}}, ctx.user, nil)
      refute ListFilters.filter(@lobby_id, lobby, %{ally_teams: %{min: 3}}, ctx.user, nil)
      refute ListFilters.filter(@lobby_id, lobby, %{ally_teams: %{max: 1}}, ctx.user, nil)
    end

    test "name contained and case insensitive", ctx do
      # name "Small Team Games"
      lobby = lobby_overview()

      assert ListFilters.filter(@lobby_id, lobby, %{name: "team"}, ctx.user, nil)
      assert ListFilters.filter(@lobby_id, lobby, %{name: "small team games"}, ctx.user, nil)
      refute ListFilters.filter(@lobby_id, lobby, %{name: "large team games"}, ctx.user, nil)
    end

    test "tags match if the lobby has any of them", ctx do
      # tags "rated" and "scav"
      lobby = lobby_overview()

      assert ListFilters.filter(@lobby_id, lobby, %{tags: MapSet.new(["rated"])}, ctx.user, nil)

      assert ListFilters.filter(
               @lobby_id,
               lobby,
               %{tags: MapSet.new(["scav", "rated"])},
               ctx.user,
               nil
             )

      refute ListFilters.filter(@lobby_id, lobby, %{tags: MapSet.new(["raptor"])}, ctx.user, nil)
    end

    test "battle in progress", ctx do
      # current_battle nil
      idle = lobby_overview()
      playing = %{lobby_overview() | current_battle: %{started_at: DateTime.utc_now()}}

      assert ListFilters.filter(@lobby_id, playing, %{battle_in_progress?: true}, ctx.user, nil)
      refute ListFilters.filter(@lobby_id, idle, %{battle_in_progress?: true}, ctx.user, nil)
      assert ListFilters.filter(@lobby_id, idle, %{battle_in_progress?: false}, ctx.user, nil)
      refute ListFilters.filter(@lobby_id, playing, %{battle_in_progress?: false}, ctx.user, nil)
    end

    test "bosses enabled", ctx do
      # boss_enabled? false
      with_boss = %{lobby_overview() | boss_enabled?: true}

      assert ListFilters.filter(@lobby_id, with_boss, %{bosses_enabled?: true}, ctx.user, nil)

      refute ListFilters.filter(
               @lobby_id,
               lobby_overview(),
               %{bosses_enabled?: true},
               ctx.user,
               nil
             )

      assert ListFilters.filter(
               @lobby_id,
               lobby_overview(),
               %{bosses_enabled?: false},
               ctx.user,
               nil
             )
    end

    test "engine and game versions", ctx do
      # engine_version "engine_v1", game_version "game_v1"
      lobby = lobby_overview()

      assert ListFilters.filter(
               @lobby_id,
               lobby,
               %{engine_versions: MapSet.new(["engine_v1", "engine_v2"])},
               ctx.user,
               nil
             )

      refute ListFilters.filter(
               @lobby_id,
               lobby,
               %{engine_versions: MapSet.new(["engine_v2"])},
               ctx.user,
               nil
             )

      assert ListFilters.filter(
               @lobby_id,
               lobby,
               %{game_versions: MapSet.new(["game_v1"])},
               ctx.user,
               nil
             )

      refute ListFilters.filter(
               @lobby_id,
               lobby,
               %{game_versions: MapSet.new(["game_v2"])},
               ctx.user,
               nil
             )
    end

    test "all filters must match", ctx do
      # map_name "Supreme That Glitters", player_count 4
      lobby = lobby_overview()

      maps = MapSet.new(["Supreme That Glitters"])

      assert ListFilters.filter(
               @lobby_id,
               lobby,
               %{map_names: maps, player_count: %{min: 2}},
               ctx.user,
               nil
             )

      refute ListFilters.filter(
               @lobby_id,
               lobby,
               %{map_names: maps, player_count: %{min: 5}},
               ctx.user,
               nil
             )
    end
  end

  describe "friends" do
    test "a friend is in the lobby", ctx do
      friend = AccountFixtures.user_fixture()
      {:ok, _friend} = Account.create_friend(ctx.user.id, friend.id)
      put_in_lobby(friend.id, @lobby_id)

      assert ListFilters.filter(@lobby_id, lobby_overview(), %{has_friend?: true}, ctx.user, nil)
      refute ListFilters.filter(@lobby_id, lobby_overview(), %{has_friend?: false}, ctx.user, nil)
    end

    test "the friend is in another lobby", ctx do
      friend = AccountFixtures.user_fixture()
      {:ok, _friend} = Account.create_friend(ctx.user.id, friend.id)
      put_in_lobby(friend.id, "other-lobby-id")

      refute ListFilters.filter(@lobby_id, lobby_overview(), %{has_friend?: true}, ctx.user, nil)
      assert ListFilters.filter(@lobby_id, lobby_overview(), %{has_friend?: false}, ctx.user, nil)
    end
  end

  describe "party members" do
    test "no party", ctx do
      refute ListFilters.filter(
               @lobby_id,
               lobby_overview(),
               %{has_party_member?: true},
               ctx.user,
               nil
             )

      assert ListFilters.filter(
               @lobby_id,
               lobby_overview(),
               %{has_party_member?: false},
               ctx.user,
               nil
             )
    end

    test "a party member is in the lobby", ctx do
      member = AccountFixtures.user_fixture()
      party_id = create_party(ctx.user.id, member.id)
      put_in_lobby(member.id, @lobby_id)

      assert ListFilters.filter(
               @lobby_id,
               lobby_overview(),
               %{has_party_member?: true},
               ctx.user,
               party_id
             )
    end

    test "the party member is in another lobby", ctx do
      member = AccountFixtures.user_fixture()
      party_id = create_party(ctx.user.id, member.id)
      put_in_lobby(member.id, "other-lobby-id")

      refute ListFilters.filter(
               @lobby_id,
               lobby_overview(),
               %{has_party_member?: true},
               ctx.user,
               party_id
             )
    end

    test "the subscribing user doesn't count", ctx do
      member = AccountFixtures.user_fixture()
      party_id = create_party(ctx.user.id, member.id)
      put_in_lobby(ctx.user.id, @lobby_id)

      refute ListFilters.filter(
               @lobby_id,
               lobby_overview(),
               %{has_party_member?: true},
               ctx.user,
               party_id
             )
    end
  end

  # Pretend there is a session for this user in the given lobby.
  # Cheating a bit but this is just testing matching part
  defp put_in_lobby(user_id, lobby_id) do
    {:ok, _owner} = SessionRegistry.register(user_id, %{lobby_id: lobby_id})
  end

  defp create_party(owner_id, member_id) do
    {:ok, %{id: party_id}} = Party.create_party(owner_id)
    {:ok, _overview} = Party.create_invite(party_id, member_id)
    {:ok, _overview} = Party.accept_invite(party_id, member_id)

    party_id
  end

  defp lobby_overview do
    %LT.ListOverview{
      counter: 0,
      name: "Small Team Games",
      player_count: 4,
      member_count: 3,
      ally_team_count: 2,
      max_player_count: 8,
      map_name: "Supreme That Glitters",
      engine_version: "engine_v1",
      game_version: "game_v1",
      boss_enabled?: false,
      current_battle: nil,
      tags: %{"rated" => %{}, "scav" => %{}}
    }
  end
end
