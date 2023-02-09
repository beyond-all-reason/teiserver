defmodule Teiserver.Account.RecacheUserStatsTask do
  @moduledoc """
  Used to recalculate certain user stats after various events
  """
  # alias Central.Repo
  # import Ecto.Query, warn: false
  alias Teiserver.{Account, Game}
  alias Teiserver.Game.MatchRatingLib
  alias Teiserver.Battle.MatchLib
  alias Teiserver.Data.Types, as: T
  import Central.Helpers.NumberHelper, only: [percent: 2]

  @spec match_processed(map(), T.userid()) :: :ok
  def match_processed(match, userid) do
    case match.game_type do
      "Duel" -> do_match_processed_duel(userid)
      "FFA" -> do_match_processed_duel(userid)
      "Team" -> do_match_processed_team(userid)
      _ -> :ok
    end
  end

  def do_match_processed_duel(userid) do
    filter_type_id = MatchRatingLib.rating_type_name_lookup()["Duel"]
    logs = Game.list_rating_logs(
      search: [
        user_id: userid,
        rating_type_id: filter_type_id,
        inserted_after: Timex.now() |> Timex.shift(days: -31)
      ],
      order_by: "Newest first",
      limit: 50,
      preload: [:match, :match_membership]
    )

    win_count = logs
      |> Enum.filter(fn log -> log.match_membership.win end)
      |> Enum.count

    loss_count = logs
      |> Enum.reject(fn log -> log.match_membership.win end)
      |> Enum.count

    total = Enum.count(logs)

    if total > 0 do
      winrate = win_count / total

      Account.update_user_stat(userid, %{
        "win_count.duel" => win_count,
        "loss_count.duel" => loss_count,
        "win_rate.duel" => winrate |> percent(1)
      })
    end

    :ok
  end

  def do_match_processed_ffa(userid) do
    filter_type_id = MatchRatingLib.rating_type_name_lookup()["FFA"]
    logs = Game.list_rating_logs(
      search: [
        user_id: userid,
        rating_type_id: filter_type_id,
        inserted_after: Timex.now() |> Timex.shift(days: -31)
      ],
      order_by: "Newest first",
      limit: 50,
      preload: [:match, :match_membership]
    )

    win_count = logs
      |> Enum.filter(fn log -> log.match_membership.win end)
      |> Enum.count

    loss_count = logs
      |> Enum.reject(fn log -> log.match_membership.win end)
      |> Enum.count

    total = Enum.count(logs)

    if total > 0 do
      winrate = win_count / total

      Account.update_user_stat(userid, %{
        "win_count.ffa" => win_count,
        "loss_count.ffa" => loss_count,
        "win_rate.ffa" => winrate |> percent(1)
      })
    end

    :ok
  end

  def do_match_processed_team(userid) do
    filter_type_id = MatchRatingLib.rating_type_name_lookup()["Team"]
    logs = Game.list_rating_logs(
      search: [
        user_id: userid,
        rating_type_id: filter_type_id,
        inserted_after: Timex.now() |> Timex.shift(days: -31)
      ],
      order_by: "Newest first",
      limit: 50,
      preload: [:match, :match_membership]
    )

    win_count = logs
      |> Enum.filter(fn log -> log.match_membership.win end)
      |> Enum.count

    loss_count = logs
      |> Enum.reject(fn log -> log.match_membership.win end)
      |> Enum.count

    statuses = logs
      |> Enum.group_by(fn log ->
        MatchLib.calculate_exit_status(log.match_membership.left_after, log.match.game_duration)
      end, fn _ ->
        1
      end)
      |> Map.new(fn {k, v} ->
        {k, Enum.count(v)}
      end)

    total = Enum.count(logs)

    if total > 0 do
      winrate = win_count / total

      Account.update_user_stat(userid, %{
        "exit_status.team.count" => total,
        "exit_status.team.stayed" => (statuses[:stayed] || 0) / total |> percent(1),
        "exit_status.team.early" => (statuses[:early] || 0) / total |> percent(1),
        "exit_status.team.abandoned" => (statuses[:abandoned] || 0) / total |> percent(1),
        "exit_status.team.noshow" => (statuses[:noshow] || 0) / total |> percent(1),
        "win_count.team" => win_count,
        "loss_count.team" => loss_count,
        "win_rate.team" => winrate |> percent(1)
      })
    end

    :ok
  end

  @spec disconnected(T.userid()) :: :ok
  def disconnected(_userid) do
    :ok
  end
end
