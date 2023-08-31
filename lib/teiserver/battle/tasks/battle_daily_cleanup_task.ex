defmodule Teiserver.Battle.Tasks.CleanupTask do
  use Oban.Worker, queue: :cleanup

  alias Teiserver.Repo
  alias Teiserver.{Battle}
  alias Teiserver.Helper.StringHelper
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

    # Tables we update
    Ecto.Adapters.SQL.query!(
      Repo,
      "UPDATE teiserver_account_accolades SET match_id = NULL WHERE match_id = ANY($1)",
      [ids]
    )

    Ecto.Adapters.SQL.query!(
      Repo,
      "UPDATE moderation_reports SET match_id = NULL WHERE match_id = ANY($1)",
      [ids]
    )

    Ecto.Adapters.SQL.query!(
      Repo,
      "UPDATE telemetry_simple_match_events SET match_id = NULL WHERE match_id = ANY($1)",
      [ids]
    )

    Ecto.Adapters.SQL.query!(
      Repo,
      "UPDATE telemetry_complex_match_events SET match_id = NULL WHERE match_id = ANY($1)",
      [ids]
    )

    Ecto.Adapters.SQL.query!(
      Repo,
      "UPDATE telemetry_simple_lobby_events SET match_id = NULL WHERE match_id = ANY($1)",
      [ids]
    )

    Ecto.Adapters.SQL.query!(
      Repo,
      "UPDATE telemetry_complex_lobby_events SET match_id = NULL WHERE match_id = ANY($1)",
      [ids]
    )

    # Match specific things we want to delete
    Ecto.Adapters.SQL.query!(
      Repo,
      "DELETE FROM teiserver_lobby_messages WHERE match_id = ANY($1)",
      [ids]
    )

    Ecto.Adapters.SQL.query!(
      Repo,
      "DELETE FROM teiserver_battle_match_memberships WHERE match_id = ANY($1)",
      [ids]
    )

    # Now delete the matches themselves
    Ecto.Adapters.SQL.query!(
      Repo,
      "DELETE FROM teiserver_battle_matches WHERE id = ANY($1)",
      [ids]
    )

    :timer.sleep(1000)
    delete_matches(remaining, nil)
  end

  defp strip_data_from_older_matches() do
    finished_before =
      Timex.now()
      |> Timex.shift(days: -@strip_data_days)

    finished_after =
      Timex.now()
      |> Timex.shift(days: -(@strip_data_days + 3))

    query = """
          UPDATE teiserver_battle_matches SET tags = '{}', data = '{}'
          WHERE finished < $1
          AND finished > $2
    """

    Ecto.Adapters.SQL.query!(Repo, query, [finished_before, finished_after])
  end
end
