defmodule Barserver.Battle.SeasonalUncertaintyResetTask do
  alias Barserver.{Account, Game}
  alias Barserver.Battle.BalanceLib
  require Logger

  @spec perform() :: :ok
  def perform() do
    start_time = System.system_time(:millisecond)

    new_last_updated = Timex.now()
    {_skill, new_uncertainty} = Openskill.rating()

    ratings_count =
      Account.list_ratings(limit: :infinity)
      |> Enum.map(fn rating ->
        reset_rating(rating, new_uncertainty, new_last_updated)
        1
      end)
      |> Enum.count()

    time_taken = System.system_time(:millisecond) - start_time

    Logger.info(
      "SeasonalUncertaintyResetTask complete, took #{time_taken}ms to reset #{ratings_count} ratings"
    )
  end

  defp reset_rating(existing, new_uncertainty, new_last_updated) do
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
end
