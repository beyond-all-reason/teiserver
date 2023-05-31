defmodule Teiserver.Battle.Tasks.DailyCleanupTask do
  use Oban.Worker, queue: :cleanup

  alias Central.Repo
  alias Teiserver.{Battle}
  import Central.Helpers.TimexHelper, only: [date_to_str: 2]

  @strip_data_days 35

  @impl Oban.Worker
  @spec perform(any) :: :ok
  def perform(_) do
    delete_unstarted_matches()
    delete_unfinished_matches()
    delete_short_matches()
    strip_data_from_older_matches()

    # Finally, delete the older matches
    delete_old_matches()

    :ok
  end

  # Teiserver.Battle.Tasks.DailyCleanupTask.delete_unstarted_matches()
  # Teiserver.Battle.Tasks.DailyCleanupTask.delete_unfinished_matches()

  def delete_unstarted_matches() do
    days = Application.get_env(:central, Teiserver)[:retention][:lobby_chat]

    # If a match is never marked as finished after X days, we delete it
    Battle.list_matches(
      search: [
        inserted_after: Timex.shift(Timex.now(), days: -days),
        has_started: false
      ],
      select: [:id],
      limit: :infinity
    )
    |> Enum.map_join(",", fn %{id: id} -> id end)
    |> delete_matches()
  end

  def delete_unfinished_matches() do
    days = Application.get_env(:central, Teiserver)[:retention][:lobby_chat]

    # If a match is never marked as finished after X days, we delete it
    Battle.list_matches(
      search: [
        inserted_after: Timex.shift(Timex.now(), days: -days),
        has_started: true,
        has_finished: false
      ],
      select: [:id],
      limit: :infinity
    )
    |> Enum.map_join(",", fn %{id: id} -> id end)
    |> delete_matches()
  end

  def delete_short_matches() do
    days = Application.get_env(:central, Teiserver)[:retention][:lobby_chat]

    # Remove tags from matches as the tags take up a lot of space and we don't need them long term
    # only need them for X days since the game, we also don't want to have to search every single game
    matches_to_process =
      Battle.list_matches(
        search: [
          inserted_before: Timex.shift(Timex.now(), days: -days),
          inserted_after: Timex.shift(Timex.now(), days: -(days * 3)),
          duration_less_than: 300
        ],
        limit: :infinity
      )
      |> Enum.filter(fn match -> match.tags != %{} end)

    # Delete short matches
    matches_to_process
    |> Enum.filter(fn match ->
      cond do
        match.finished == nil ->
          true

        match.started == nil ->
          true

        true ->
          duration = Timex.diff(match.finished, match.started, :second)
          duration < Application.get_env(:central, Teiserver)[:retention][:battle_minimum_seconds]
      end
    end)
    |> Enum.map_join(",", fn %{id: id} -> id end)
    |> delete_matches()
  end

  def delete_old_matches() do
    # Rated matches
    battle_match_rated_days =
      Application.get_env(:central, Teiserver)[:retention][:battle_match_rated]

    Battle.list_matches(
      search: [
        inserted_before: Timex.shift(Timex.now(), days: -battle_match_rated_days),
        game_type_in: ["Team", "Duel", "FFA", "Team FFA"]
      ],
      search: [:id],
      limit: :infinity
    )
    |> Enum.map_join(",", fn %{id: id} -> id end)
    |> delete_matches

    # Unrated matches
    battle_match_unrated_days =
      Application.get_env(:central, Teiserver)[:retention][:battle_match_unrated]

    Battle.list_matches(
      search: [
        inserted_before: Timex.shift(Timex.now(), days: -battle_match_unrated_days),
        game_type_not_in: ["Team", "Duel", "FFA", "Team FFA"]
      ],
      search: [:id],
      limit: :infinity
    )
    |> Enum.map_join(",", fn %{id: id} -> id end)
    |> delete_matches
  end

  defp delete_matches(""), do: :ok

  defp delete_matches(ids) do
    query = """
          UPDATE teiserver_account_accolades SET match_id = NULL
          WHERE match_id IN (#{ids})
    """

    Ecto.Adapters.SQL.query(Repo, query, [])

    query = """
          DELETE FROM teiserver_battle_match_memberships
          WHERE match_id IN (#{ids})
    """

    Ecto.Adapters.SQL.query(Repo, query, [])

    query = """
          DELETE FROM teiserver_battle_matches
          WHERE id IN (#{ids})
    """

    Ecto.Adapters.SQL.query(Repo, query, [])
  end

  defp strip_data_from_older_matches() do
    finished_before =
      Timex.now()
      |> Timex.shift(days: -@strip_data_days)
      |> date_to_str(:ymd_t_hms)

    query = """
          UPDATE teiserver_battle_matches m SET tags = '{}'
          WHERE m.finished < #{finished_before}
    """

    Ecto.Adapters.SQL.query(Repo, query, [])
  end
end
