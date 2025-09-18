defmodule Teiserver.Account.SmurfMergeTask do
  @moduledoc false
  alias Teiserver.{Account, Game}
  alias Teiserver.Battle.BalanceLib
  require Logger
  alias Teiserver.Data.Types, as: T
  # alias Teiserver.Repo

  @spec perform(T.userid(), T.userid(), map()) :: :ok
  def perform(from_id, to_id, settings) do
    merge_ratings(from_id, to_id, settings["ratings"])
    # merge_actions(from_id, to_id, settings["reports"])
    merge_names(from_id, to_id, settings["names"])
    merge_mutes(from_id, to_id, settings["mutes"])

    :ok
  end

  # defp merge_actions(from_id, to_id, "true") do
  #   fields = ~w(target_id location location_id reason reporter_id response_text response_action followup code_references action_data responded_at expires responder_id inserted_at updated_at)a

  #   new_reports = Account.list_reports(
  #     search: [target_id: from_id],
  #     limit: :infinity
  #   )
  #     |> Enum.map(fn report ->
  #       fields
  #         |> Map.new(fn k ->
  #           {k, Map.get(report, k)}
  #         end)
  #         |> Map.put(:target_id, to_id)
  #     end)

  #   Ecto.Multi.new()
  #     |> Ecto.Multi.insert_all(:insert_all, Teiserver.Account.Report, new_reports)
  #     |> Repo.transaction()

  #   :ok
  # end
  # defp merge_actions(_from_id, _to_id, "false"), do: :ok

  @spec merge_ratings(T.userid(), T.userid(), String.t()) :: :ok
  defp merge_ratings(_from_id, _to_id, "false"), do: :ok

  defp merge_ratings(from_id, to_id, "true") do
    season = Teiserver.Game.MatchRatingLib.active_season()

    to_ratings =
      Account.list_ratings(search: [user_id: to_id, season: season])
      |> Map.new(fn r -> {r.rating_type_id, r} end)

    # Now we go through the ratings of the from player and act
    Account.list_ratings(search: [user_id: from_id, season: season])
    |> Enum.each(fn from_rating ->
      rating_type_id = from_rating.rating_type_id
      to_rating = to_ratings[rating_type_id] || BalanceLib.default_rating()

      from_value = BalanceLib.convert_rating(from_rating)
      to_value = BalanceLib.convert_rating(to_rating)

      if from_value > to_value do
        {:ok, _rating} =
          Account.create_or_update_rating(%{
            user_id: to_id,
            rating_type_id: rating_type_id,
            rating_value: from_rating.rating_value,
            skill: from_rating.skill,
            uncertainty: from_rating.uncertainty,
            leaderboard_rating: from_rating.leaderboard_rating,
            last_updated: Timex.now(),
            season: season
          })

        {:ok, _log} =
          Game.create_rating_log(%{
            user_id: to_id,
            rating_type_id: rating_type_id,
            match_id: nil,
            inserted_at: Timex.now(),
            season: season,
            value: %{
              reason: "Smurf adjustment",
              rating_value: from_rating.rating_value,
              skill: from_rating.skill,
              uncertainty: from_rating.uncertainty,
              rating_value_change: from_rating.rating_value - to_rating.rating_value,
              skill_change: from_rating.skill - to_rating.skill,
              uncertainty_change: from_rating.uncertainty - to_rating.uncertainty
            }
          })
      end
    end)
  end

  @spec merge_names(T.userid(), T.userid(), String.t()) :: :ok
  defp merge_names(_from_id, _to_id, "false"), do: :ok

  defp merge_names(from_id, to_id, "true") do
    previous_names =
      Account.get_user_stat_data(from_id)
      |> Map.get("previous_names", [])

    current_name = Account.get_username_by_id(from_id)

    to_previous =
      Account.get_user_stat_data(to_id)
      |> Map.get("previous_names", [])

    new_previous =
      (to_previous ++ [current_name | previous_names])
      |> Enum.uniq()

    Account.update_user_stat(to_id, %{"previous_names" => new_previous})
  end

  @spec merge_mutes(T.userid(), T.userid(), String.t()) :: :ok
  defp merge_mutes(_from_id, _to_id, "false"), do: :ok

  defp merge_mutes(from_id, to_id, "true") do
    Account.list_users(
      search: [
        data_contains_number: {"ignored", from_id}
      ],
      select: [:id],
      limit: :infinity
    )
    |> Enum.each(fn %{id: ignorer_id} ->
      case Account.ignore_user(ignorer_id, to_id) do
        {:ok, _} ->
          :ok

        {:error, reason} ->
          Logger.warning("Failed to ignore user #{to_id} for #{ignorer_id}: #{reason}")
      end
    end)

    :ok
  end
end
