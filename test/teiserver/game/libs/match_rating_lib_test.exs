defmodule Teiserver.Game.MatchRatingLibTest do
  @moduledoc false
  use Teiserver.DataCase, async: true
  alias Teiserver.Game.MatchRatingLib
  alias Teiserver.Account.AccountTestLib
  alias Teiserver.Battle.MatchLib
  alias Teiserver.Account
  alias Teiserver.Battle
  alias Teiserver.Game
  alias Teiserver.Config

  test "num_matches is updated after rating a match" do
    # Create two user
    user1 = AccountTestLib.user_fixture()
    user2 = AccountTestLib.user_fixture()

    match = create_fake_match(user1.id, user2.id)

    ratings =
      Account.list_ratings(
        search: [
          rating_type_id: rating_type_id,
          user_id_in: [user1.id, user2.id]
        ]
      )
      |> Map.new(fn rating ->
        {rating.user_id, rating}
      end)

    assert ratings[user1.id] == nil
    assert ratings[user2.id] == nil

    MatchRatingLib.rate_match(match.id)

    # Check ratings of users after match
    ratings = get_ratings([user1.id, user2.id], match.game_type)

    assert ratings[user1.id].skill == 27.637760127073694
    assert ratings[user2.id].skill == 22.362239872926306

    assert ratings[user1.id].num_matches == 1
    assert ratings[user1.id].num_matches == 1

    # Create another match
    match = create_fake_match(user1.id, user2.id)
    MatchRatingLib.rate_match(match.id)

    # Check ratings of users after match
    ratings = get_ratings([user1.id, user2.id], match.game_type)

    assert ratings[user1.id].skill == 29.662576313923775
    assert ratings[user2.id].skill == 20.337423686076225

    # Check num_matches has increased
    assert ratings[user1.id].num_matches == 2
    assert ratings[user1.id].num_matches == 2

    # Rerate the same match
    MatchRatingLib.re_rate_specific_matches([match.id])

    # Check num_matches unchanged
    assert ratings[user1.id].num_matches == 2
    assert ratings[user1.id].num_matches == 2
  end

  describe "Test rating system where new players start at zero" do
    test "rating after one match" do
      # Set config to use provisional ratings
      Config.update_site_config("hidden.Rating method", "start at zero; converge to skill")

      # Create two user
      user1 = AccountTestLib.user_fixture()
      user2 = AccountTestLib.user_fixture()

      match = create_fake_match(user1.id, user2.id)

      MatchRatingLib.rate_match(match.id)

      # Check ratings of users after match
      ratings = get_ratings([user1.id, user2.id], match.game_type)

      assert ratings[user1.id].skill == 27.637760127073694
      assert ratings[user2.id].skill == 22.362239872926306

      # New players start at zero then converge to skill over time
      assert ratings[user1.id].rating_value == 0.9212586709024565
      assert ratings[user2.id].rating_value == 0.7454079957642102
    end

    test "rating after many matches" do
      # Set config to use provisional ratings
      Config.update_site_config("hidden.Rating method", "start at zero; converge to skill")

      # Create two user
      user1 = AccountTestLib.user_fixture()
      user2 = AccountTestLib.user_fixture()

      matches_target =
        Config.get_site_config_cache("profile.Num matches for rating to equal skill")

      match_ids = 1..matches_target

      matches =
        Enum.map(match_ids, fn x ->
          match = create_fake_match(user1.id, user2.id)

          MatchRatingLib.rate_match(match.id)

          match
        end)

      # Check ratings of users after match
      ratings = get_ratings([user1.id, user2.id], Enum.at(matches, 0).game_type)

      assert ratings[user1.id].skill == 41.851075350620384
      assert ratings[user2.id].skill == 8.148924649379609

      # Rating should equal skill
      assert ratings[user1.id].rating_value == ratings[user1.id].skill
      assert ratings[user2.id].rating_value == ratings[user2.id].skill

      # Rate one more match and rating should still equal skill since we've hit the matches_target
      match = create_fake_match(user1.id, user2.id)
      MatchRatingLib.rate_match(match.id)
      # Check ratings of users after match
      ratings = get_ratings([user1.id, user2.id], rating_type_id)

      # Rating should equal skill
      assert ratings[user1.id].rating_value == ratings[user1.id].skill
      assert ratings[user2.id].rating_value == ratings[user2.id].skill
    end
  end

  describe "Test rating system where rating = skill minus uncertainty" do
    test "rating after one match" do
      # Set config to use provisional ratings
      Config.update_site_config("hidden.Rating method", "skill minus uncertainty")

      # Create two user
      user1 = AccountTestLib.user_fixture()
      user2 = AccountTestLib.user_fixture()

      match = create_fake_match(user1.id, user2.id)

      MatchRatingLib.rate_match(match.id)

      # Check ratings of users after match
      ratings = get_ratings([user1.id, user2.id], match.game_type)

      assert ratings[user1.id].skill == 27.637760127073694
      assert ratings[user2.id].skill == 22.362239872926306

      assert ratings[user1.id].rating_value ==
               ratings[user1.id].skill - ratings[user1.id].uncertainty

      assert ratings[user2.id].rating_value ==
               ratings[user2.id].skill - ratings[user2.id].uncertainty
    end
  end

  defp get_ratings(userids, game_type) do
    rating_type_id = Game.get_or_add_rating_type(game_type)

    Account.list_ratings(
      search: [
        rating_type_id: rating_type_id,
        user_id_in: userids
      ]
    )
    |> Map.new(fn rating ->
      {rating.user_id, rating}
    end)
  end

  defp create_fake_match(user1_id, user2_id) do
    team_count = 2
    team_size = 1
    game_type = MatchLib.game_type(team_size, team_count)
    server_uuid = UUID.uuid1()
    end_time = Timex.now()

    start_time = DateTime.add(end_time, 50, :minute)

    # Create a match
    {:ok, match} =
      Battle.create_match(%{
        server_uuid: server_uuid,
        uuid: UUID.uuid1(),
        map: "Koom valley",
        data: %{},
        tags: %{},
        winning_team: 0,
        team_count: team_count,
        team_size: team_size,
        passworded: false,
        processed: true,
        game_type: game_type,
        # All rooms are hosted by the same user for now
        founder_id: 1,
        bots: %{},
        queue_id: nil,
        started: start_time,
        finished: end_time
      })

    # Create match memberships
    memberships1 = [
      %{
        team_id: 0,
        win: match.winning_team == 0,
        stats: %{},
        party_id: nil,
        user_id: user1_id,
        match_id: match.id
      }
    ]

    memberships2 = [
      %{
        team_id: 1,
        win: match.winning_team == 1,
        stats: %{},
        party_id: nil,
        user_id: user2_id,
        match_id: match.id
      }
    ]

    Ecto.Multi.new()
    |> Ecto.Multi.insert_all(
      :insert_all,
      Battle.MatchMembership,
      memberships1 ++ memberships2
    )
    |> Teiserver.Repo.transaction()

    match
  end
end
