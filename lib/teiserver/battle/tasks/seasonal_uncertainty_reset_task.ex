defmodule Teiserver.Battle.SeasonalUncertaintyResetTask do
  alias Teiserver.{Account, Game}
  alias Teiserver.Battle.BalanceLib
  require Logger

  @spec perform() :: :ok
  def perform() do
    start_time = System.system_time(:millisecond)

    new_last_updated = Timex.now()

    ratings_count =
      Account.list_ratings(limit: :infinity)
      |> Enum.map(fn rating ->
        reset_rating(rating, new_last_updated)
        1
      end)
      |> Enum.count()

    time_taken = System.system_time(:millisecond) - start_time

    Logger.info(
      "SeasonalUncertaintyResetTask complete, took #{time_taken}ms to reset #{ratings_count} ratings"
    )
  end

  defp reset_rating(existing, new_last_updated) do
    # Use the greater of the existing uncertainty or the minimum value (5.0)
    current_uncertainty = existing.uncertainty
    # datetime
    last_updated = existing.last_updated

    new_uncertainty = calculate_new_uncertainty(current_uncertainty, last_updated)

    new_rating_value = BalanceLib.calculate_rating_value(existing.skill, new_uncertainty)

    new_leaderboard_rating =
      BalanceLib.calculate_leaderboard_rating(existing.skill, new_uncertainty)

    Account.update_rating(existing, %{
      rating_value: new_rating_value,
      uncertainty: new_uncertainty,
      leaderboard_rating: new_leaderboard_rating,
      last_updated: new_last_updated
    })

    log_params = %{
      user_id: existing.user_id,
      rating_type_id: existing.rating_type_id,
      match_id: nil,
      inserted_at: new_last_updated,
      value: %{
        reason: "Seasonal reset",
        rating_value: new_rating_value,
        skill: existing.skill,
        uncertainty: new_uncertainty,
        rating_value_change: new_rating_value - existing.rating_value,
        skill_change: 0,
        uncertainty_change: new_uncertainty - existing.uncertainty
      }
    }

    {:ok, _} = Game.create_rating_log(log_params)
  end

  def calculate_new_uncertainty(current_uncertainty, last_update_datetime) do
    days_not_played = abs(DateTime.diff(last_update_datetime, Timex.now(), :day))
    target_uncertainty = calculate_target_uncertainty(days_not_played)
    # The new uncertainty can increase but never decrease
    max(target_uncertainty, current_uncertainty)
  end

  # This is the player's new target uncertainty
  # If the player hasn't played for a while, their target uncertainty will be higher
  def calculate_target_uncertainty(days_not_played) do
    # If you haven't played for more than a year reset uncertainty to default
    # If you have played within one month, then the target uncertainty equals min_uncertainty
    # If it's something in between one month and a year, use linear interpolation
    # Linear interpolation formula: https://www.cuemath.com/linear-interpolation-formula/
    one_year = 365
    one_month = one_year / 12
    min_uncertainty = 5
    {_skill, max_uncertainty} = Openskill.rating()

    cond do
      days_not_played >= one_year ->
        max_uncertainty

      days_not_played <= one_month ->
        min_uncertainty

      true ->
        max_days = one_year
        min_days = one_month

        # linear interpolation will give a value between min_uncertainty and max_uncertainty
        min_uncertainty +
          (days_not_played - min_days) * (max_uncertainty - min_uncertainty) /
            (max_days - min_days)
    end
  end
end
