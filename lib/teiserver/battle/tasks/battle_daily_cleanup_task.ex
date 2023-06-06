defmodule Teiserver.Battle.Tasks.DailyCleanupTask do
  use Oban.Worker, queue: :cleanup

  alias Central.Repo
  alias Teiserver.{Battle}
  alias Central.Helpers.StringHelper
  import Central.Helpers.TimexHelper, only: [date_to_str: 2]
  require Logger

  @strip_data_days 35
  @chunk_size 5

  @impl Oban.Worker
  @spec perform(any) :: :ok
  def perform(_) do
    start_time = System.system_time(:millisecond)

    delete_unstarted_matches()
    delete_unfinished_matches()
    strip_data_from_older_matches()

    # Finally, delete the older matches
    delete_old_matches()

    time_taken = System.system_time(:millisecond) - start_time
    Logger.info("#{__MODULE__} execution, took #{StringHelper.format_number(time_taken)}ms")

    :ok
  end

  defp get_days() do
    Application.get_env(:central, Teiserver)[:retention][:lobby_chat] + 1
  end

  def delete_unstarted_matches() do
    # If a match is never marked as finished after X days, we delete it
    Battle.list_matches(
      search: [
        inserted_before: Timex.shift(Timex.now(), days: -get_days()),
        has_started: false,
        rated: false
      ],
      select: [:id],
      limit: :infinity
    )
    |> Enum.map(fn %{id: id} -> id end)
    |> delete_matches("unstarted")
  end

  def delete_unfinished_matches() do
    # If a match is never marked as finished after X days, we delete it
    Battle.list_matches(
      search: [
        inserted_before: Timex.shift(Timex.now(), days: -get_days()),
        has_started: true,
        has_finished: false,
        rated: false
      ],
      select: [:id],
      limit: :infinity
    )
    |> Enum.map(fn %{id: id} -> id end)
    |> delete_matches("unfinished")
  end

  def delete_old_matches() do
    # Rated matches - We don't delete them, they have rating logs attached to them
    # battle_match_rated_days =
    #   Application.get_env(:central, Teiserver)[:retention][:battle_match_rated]

    # Battle.list_matches(
    #   search: [
    #     inserted_before: Timex.shift(Timex.now(), days: -battle_match_rated_days),
    #     game_type_in: ["Team", "Duel", "FFA", "Team FFA"]
    #   ],
    #   search: [:id],
    #   limit: :infinity
    # )
    # |> Enum.map(fn %{id: id} -> id end)
    # |> delete_matches("old rated")

    # Unrated matches
    battle_match_unrated_days =
      Application.get_env(:central, Teiserver)[:retention][:battle_match_unrated]

    Battle.list_matches(
      search: [
        inserted_before: Timex.shift(Timex.now(), days: -battle_match_unrated_days),
        rated: false
      ],
      search: [:id],
      limit: :infinity
    )
    |> Enum.map(fn %{id: id} -> id end)
    |> delete_matches("old unrated")
  end

  def delete_matches([], _), do: :ok

  def delete_matches(ids, _logger_set) do
    ids = Enum.take(ids, @chunk_size * 100)
    {ids, remaining} = Enum.split(ids, @chunk_size)

    id_str = Enum.join(ids, ",")

    # Tables we update
    {:ok, _} =
      Ecto.Adapters.SQL.query(
        Repo,
        "UPDATE teiserver_account_accolades SET match_id = NULL WHERE match_id IN (#{id_str})",
        []
      )

    {:ok, _} =
      Ecto.Adapters.SQL.query(
        Repo,
        "UPDATE moderation_reports SET match_id = NULL WHERE match_id IN (#{id_str})",
        []
      )

    {:ok, _} =
      Ecto.Adapters.SQL.query(
        Repo,
        "UPDATE teiserver_telemetry_match_events SET match_id = NULL WHERE match_id IN (#{id_str})",
        []
      )

    # Match specific things we want to delete
    {:ok, _} =
      Ecto.Adapters.SQL.query(
        Repo,
        "DELETE FROM teiserver_lobby_messages WHERE match_id IN (#{id_str})",
        []
      )

    {:ok, _} =
      Ecto.Adapters.SQL.query(
        Repo,
        "DELETE FROM teiserver_battle_match_memberships WHERE match_id IN (#{id_str})",
        []
      )

    # Now delete the matches themselves
    {:ok, _} =
      Ecto.Adapters.SQL.query(
        Repo,
        "DELETE FROM teiserver_battle_matches WHERE id IN (#{id_str})",
        []
      )

    :timer.sleep(500)
    delete_matches(remaining, nil)
  end

  defp strip_data_from_older_matches() do
    finished_before =
      Timex.now()
      |> Timex.shift(days: -@strip_data_days)
      |> date_to_str(:ymd_t_hms)

    finished_after =
      Timex.now()
      |> Timex.shift(days: -(@strip_data_days * 2))
      |> date_to_str(:ymd_t_hms)

    query = """
          UPDATE teiserver_battle_matches m SET tags = '{}' data = '{}'
          WHERE m.finished < #{finished_before}
          AND m.finished > #{finished_after}
    """

    Ecto.Adapters.SQL.query(Repo, query, [])
  end
end
