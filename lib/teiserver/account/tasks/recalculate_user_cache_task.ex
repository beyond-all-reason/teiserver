defmodule Teiserver.Account.RecacheUserStatsTask do
  @moduledoc """
  Used to recalculate certain user stats after various events
  """
  # alias Teiserver.Repo
  # import Ecto.Query, warn: false
  alias Teiserver.{Account, Game}
  alias Teiserver.Game.MatchRatingLib
  alias Teiserver.Battle.MatchLib
  alias Teiserver.Data.Types, as: T
  alias Teiserver.Helper.TimexHelper
  import Teiserver.Helper.NumberHelper, only: [percent: 2]

  @match_cache_recent_days 7
  @match_cache_max_days 31

  @spec match_processed(map(), T.userid()) :: no_return()
  def match_processed(match, userid) do
    case match.game_type do
      "Duel" -> do_match_processed_duel(userid)
      "FFA" -> do_match_processed_duel(userid)
      "Small Team" -> do_match_processed_team_small(userid)
      "Large Team" -> do_match_processed_team_large(userid)
      _ -> :ok
    end

    # And now update the last_played timestamp
    Account.update_cache_user(userid, %{last_played: match.started})
  end

  def do_match_processed_duel(userid) do
    filter_type_id = MatchRatingLib.rating_type_name_lookup()["Duel"]

    logs =
      Game.list_rating_logs(
        search: [
          user_id: userid,
          rating_type_id: filter_type_id,
          inserted_after: Timex.now() |> Timex.shift(days: -@match_cache_max_days)
        ],
        order_by: "Newest first",
        limit: 50,
        preload: [:match_membership]
      )

    win_count =
      logs
      |> Enum.count(fn log -> log.match_membership.win end)

    loss_count =
      logs
      |> Enum.count(fn log -> not log.match_membership.win end)

    total = Enum.count(logs)

    if total > 0 do
      winrate = win_count / total

      Account.update_user_stat(userid, %{
        "recent_count.duel" => total,
        "win_count.duel" => win_count,
        "loss_count.duel" => loss_count,
        "win_rate.duel" => winrate |> percent(1)
      })
    end

    :ok
  end

  def do_match_processed_ffa(userid) do
    filter_type_id = MatchRatingLib.rating_type_name_lookup()["FFA"]

    logs =
      Game.list_rating_logs(
        search: [
          user_id: userid,
          rating_type_id: filter_type_id,
          inserted_after: Timex.now() |> Timex.shift(days: -@match_cache_max_days)
        ],
        order_by: "Newest first",
        limit: 50,
        preload: [:match_membership]
      )

    win_count =
      logs
      |> Enum.count(fn log -> log.match_membership.win end)

    loss_count =
      logs
      |> Enum.count(fn log -> not log.match_membership.win end)

    total = Enum.count(logs)

    if total > 0 do
      winrate = win_count / total

      Account.update_user_stat(userid, %{
        "recent_count.ffa" => total,
        "win_count.ffa" => win_count,
        "loss_count.ffa" => loss_count,
        "win_rate.ffa" => winrate |> percent(1)
      })
    end

    :ok
  end

  def do_match_processed_team_large(userid) do
    do_match_processed_team(userid, "Large Team")
  end

  def do_match_processed_team_small(userid) do
    do_match_processed_team(userid, "Small Team")
  end

  defp do_match_processed_team(userid, team_subtype) do
    filter_type_id = MatchRatingLib.rating_type_name_lookup()[team_subtype]

    logs =
      Game.list_rating_logs(
        search: [
          user_id: userid,
          rating_type_id: filter_type_id,
          inserted_after: Timex.now() |> Timex.shift(days: -@match_cache_max_days)
        ],
        order_by: "Newest first",
        limit: 50,
        preload: [:match, :match_membership]
      )

    win_count =
      logs
      |> Enum.count(fn log -> log.match_membership.win end)

    loss_count =
      logs
      |> Enum.count(fn log -> not log.match_membership.win end)

    statuses =
      logs
      |> Enum.group_by(
        fn log ->
          MatchLib.calculate_exit_status(log.match_membership.left_after, log.match.game_duration)
        end,
        fn _ ->
          1
        end
      )
      |> Map.new(fn {k, v} ->
        {k, Enum.count(v)}
      end)

    team_type =
      team_subtype
      |> String.downcase()
      |> String.replace(" ", "_")

    total = Enum.count(logs)

    if total > 0 do
      winrate = win_count / total

      Account.update_user_stat(userid, %{
        "exit_status.#{team_type}.count" => total,
        "exit_status.#{team_type}.stayed" => ((statuses[:stayed] || 0) / total) |> percent(1),
        "exit_status.#{team_type}.early" => ((statuses[:early] || 0) / total) |> percent(1),
        "exit_status.#{team_type}.abandoned" =>
          ((statuses[:abandoned] || 0) / total) |> percent(1),
        "exit_status.#{team_type}.noshow" => ((statuses[:noshow] || 0) / total) |> percent(1),
        "recent_count.#{team_type}" => total,
        "win_count.#{team_type}" => win_count,
        "loss_count.#{team_type}" => loss_count,
        "win_rate.#{team_type}" => winrate |> percent(1)
      })
    end

    # For team we also look at their really recent games as that's where we'd expect
    # smurfs to be most active right now
    do_match_processed_team_recent(userid, logs, team_type)
    :ok
  end

  def do_match_processed_team_recent(userid, logs, team_type) do
    # Filter down to just the recent ones rather than re-running the query
    timestamp_after = Timex.now() |> Timex.shift(days: -@match_cache_recent_days)

    logs =
      logs
      |> Enum.filter(fn log ->
        TimexHelper.greater_than(log.inserted_at, timestamp_after)
      end)
      |> Enum.take(15)

    win_count =
      logs
      |> Enum.count(fn log -> log.match_membership.win end)

    loss_count =
      logs
      |> Enum.count(fn log -> not log.match_membership.win end)

    statuses =
      logs
      |> Enum.group_by(
        fn log ->
          MatchLib.calculate_exit_status(log.match_membership.left_after, log.match.game_duration)
        end,
        fn _ ->
          1
        end
      )
      |> Map.new(fn {k, v} ->
        {k, Enum.count(v)}
      end)

    total = Enum.count(logs)

    if total > 0 do
      winrate = win_count / total

      Account.update_user_stat(userid, %{
        "exit_status.#{team_type}_recent.count" => total,
        "exit_status.#{team_type}_recent.stayed" =>
          ((statuses[:stayed] || 0) / total) |> percent(1),
        "exit_status.#{team_type}_recent.early" =>
          ((statuses[:early] || 0) / total) |> percent(1),
        "exit_status.#{team_type}_recent.abandoned" =>
          ((statuses[:abandoned] || 0) / total) |> percent(1),
        "exit_status.#{team_type}_recent.noshow" =>
          ((statuses[:noshow] || 0) / total) |> percent(1),
        "recent_count.#{team_type}_recent" => total,
        "win_count.#{team_type}_recent" => win_count,
        "loss_count.#{team_type}_recent" => loss_count,
        "win_rate.#{team_type}_recent" => winrate |> percent(1)
      })
    end

    :ok
  end

  @spec disconnected(T.userid()) :: :ok
  def disconnected(_userid) do
    :ok
  end
end
