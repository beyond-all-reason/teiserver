defmodule Teiserver.TestUtil.BalancerUtil do
@moduledoc """
This module is used by BalancerData module
"""
  alias Teiserver.{Account, CacheUser }
  alias Teiserver.Game.MatchRatingLib

  #Update the database with player minutes
  def update_stats(username, player_minutes, os) do
    user = Teiserver.Account.UserCacheLib.get_user_by_name(username)
    user_id = user.id
    Account.update_user_stat(user_id, %{
      player_minutes: player_minutes,
      total_minutes: player_minutes
    })

    #Now recalculate ranks
    #This calc would usually be done in do_login
    rank= CacheUser.calculate_rank(user_id)
    user = %{
      user
      |
        rank: rank,
    }
    CacheUser.update_user(user, true)
    update_rating(user.id, os)
  end

  defp update_rating(user_id, os) do
    new_uncertainty = 6
    new_skill = os + new_uncertainty
    new_rating_value = os
    new_leaderboard_rating = os - 2*new_uncertainty
    rating_type = "Team"
    rating_type_id = MatchRatingLib.rating_type_name_lookup()[rating_type]
    case Account.get_rating(user_id, rating_type_id) do
      nil ->
        Account.create_rating(%{
          user_id: user_id,
          rating_type_id: rating_type_id,
          rating_value: new_rating_value,
          skill: new_skill,
          uncertainty: new_uncertainty,
          leaderboard_rating: new_leaderboard_rating,
          last_updated: Timex.now()
        })

      existing ->
        Account.update_rating(existing, %{
          rating_value: new_rating_value,
          skill: new_skill,
          uncertainty: new_uncertainty,
          leaderboard_rating: new_leaderboard_rating,
          last_updated: Timex.now()
        })
    end

  end

end
