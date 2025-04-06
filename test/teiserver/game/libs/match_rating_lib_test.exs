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

  test "num_matches and num_wins is updated after rating a match" do
    # Create two user
    user1 = AccountTestLib.user_fixture()
    user2 = AccountTestLib.user_fixture()

    match = create_fake_match(user1.id, user2.id)

    # Check ratings of users before we rate the match
    rating_type_id = Game.get_or_add_rating_type(match.game_type)
    season = MatchRatingLib.active_season()

    ratings =
      Account.list_ratings(
        search: [
          rating_type_id: rating_type_id,
          user_id_in: [user1.id, user2.id],
          season: season
        ]
      )
      |> Map.new(fn rating ->
        {rating.user_id, rating}
      end)

    assert ratings[user1.id] == nil
    assert ratings[user2.id] == nil

    MatchRatingLib.rate_match(match.id)

    # Check ratings of users after match
    ratings = get_ratings([user1.id, user2.id], rating_type_id)

    assert ratings[user1.id].skill == 27.637760127073694
    assert ratings[user2.id].skill == 22.362239872926306

    # Check num_matches and num_wins in teiserver_account_ratings table
    assert ratings[user1.id].num_matches == 1
    assert ratings[user2.id].num_matches == 1
    assert ratings[user1.id].num_wins == 1
    assert ratings[user2.id].num_wins == 0

    # Check num_matches and num_wins in teiserver_game_rating_logs table
    rating_logs =
      Game.list_rating_logs(
        search: [
          match_id: match.id,
          season: season
        ],
        limit: :infinity
      )

    assert Enum.at(rating_logs, 0).value["num_matches"] == 1
    assert Enum.at(rating_logs, 0).value["num_wins"] == 1
    assert Enum.at(rating_logs, 1).value["num_matches"] == 1
    assert Enum.at(rating_logs, 1).value["num_wins"] == 0

    # Create another match
    match = create_fake_match(user1.id, user2.id)
    MatchRatingLib.rate_match(match.id)

    # Check ratings of users after match
    ratings = get_ratings([user1.id, user2.id], rating_type_id)

    assert ratings[user1.id].skill == 29.662576313923775
    assert ratings[user2.id].skill == 20.337423686076225

    # Check num_matches and num_wins has increased
    assert ratings[user1.id].num_matches == 2
    assert ratings[user2.id].num_matches == 2
    assert ratings[user1.id].num_wins == 2
    assert ratings[user2.id].num_wins == 0

    # Rerate the same match
    MatchRatingLib.re_rate_specific_matches([match.id])

    # Check num_matches and num_wins unchanged
    assert ratings[user1.id].num_matches == 2
    assert ratings[user2.id].num_matches == 2
    assert ratings[user1.id].num_wins == 2
    assert ratings[user2.id].num_wins == 0

    # Check total_matches and total_wins are correct
    # num_matches and total_matches should be the same because they have only played in one season
    assert ratings[user1.id].total_matches == 2
    assert ratings[user2.id].total_matches == 2
    assert ratings[user1.id].total_wins == 2
    assert ratings[user2.id].total_wins == 0
  end

  test "tau in config is used when rating matches" do
    # Create two user
    user1 = AccountTestLib.user_fixture()
    user2 = AccountTestLib.user_fixture()

    match = create_fake_match(user1.id, user2.id)
    rating_type_id = Game.get_or_add_rating_type(match.game_type)

    MatchRatingLib.rate_match(match.id)

    # Check ratings of users after match
    ratings = get_ratings([user1.id, user2.id], rating_type_id)

    # Remember the new uncertainty after 1 match when using default tau
    expected_uncertainty_default_tau = ratings[user1.id].uncertainty
    # Both users will have same uncertainty
    assert ratings[user1.id].uncertainty == ratings[user2.id].uncertainty

    # Change tau in config to a lower number
    Config.update_site_config("rating.Tau", 0)

    # Create two user
    user1 = AccountTestLib.user_fixture()
    user2 = AccountTestLib.user_fixture()

    match = create_fake_match(user1.id, user2.id)
    rating_type_id = Game.get_or_add_rating_type(match.game_type)

    MatchRatingLib.rate_match(match.id)

    # Check ratings of users after match
    ratings = get_ratings([user1.id, user2.id], rating_type_id)

    # Lower value of tau means that uncertainty drops MORE
    assert ratings[user1.id].uncertainty < expected_uncertainty_default_tau
    assert ratings[user1.id].uncertainty == ratings[user2.id].uncertainty

    reset_to_default_tau()
  end

  defp reset_to_default_tau() do
    Config.delete_site_config("rating.Tau")
  end

  defp get_ratings(userids, rating_type_id) do
    Account.list_ratings(
      search: [
        rating_type_id: rating_type_id,
        user_id_in: userids,
        season: MatchRatingLib.active_season()
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
