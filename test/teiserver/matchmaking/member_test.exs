defmodule Teiserver.Matchmaking.MemberTest do
  alias Central.Helpers.GeneralTestLib
  alias Teiserver.Account
  alias Teiserver.Game
  alias Teiserver.Game.MatchRatingLib
  alias Teiserver.Matchmaking.Member
  alias Teiserver.Support.Tachyon

  use Teiserver.DataCase

  describe "get_member_rating" do
    test "no rating for user" do
      user = GeneralTestLib.make_user(%{"roles" => ["Verified"]})

      assert Member.get_member_rating([user.id], "Duel") == %{
               skill: 16.666666666666664,
               uncertainty: 8.333333333333334
             }
    end

    test "rating for a user" do
      user = Tachyon.create_user()
      rating_attrs(user.id, "Duel", 31, 3.5) |> set_rating!()
      assert Member.get_member_rating([user.id], "Duel") == %{skill: 31, uncertainty: 3.5}
    end

    test "average of ratings" do
      [u1, u2] = [Tachyon.create_user(), Tachyon.create_user()]
      rating_attrs(u1.id, "Duel", 30, 2) |> set_rating!()
      rating_attrs(u2.id, "Duel", 50, 4) |> set_rating!()
      assert Member.get_member_rating([u1.id, u2.id], "Duel") == %{skill: 40, uncertainty: 3}
    end
  end

  defp rating_attrs(user_id, game_type, rating, uncertainty) do
    rt = Game.get_rating_type_by_name!(game_type)

    %{
      user_id: user_id,
      rating_type_id: rt.id,
      rating_value: max(rating - uncertainty, 0),
      skill: rating,
      uncertainty: uncertainty,
      # leaderboard rating is irrelevant for these tests
      leaderboard_rating: 10,
      last_updated: DateTime.utc_now(),
      season: MatchRatingLib.active_season()
    }
  end

  defp set_rating!(attrs) do
    {:ok, r} = Account.create_or_update_rating(attrs)
    r
  end
end
