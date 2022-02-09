defmodule Teiserver.Battle.Tasks.DailyCleanupTask do
  use Oban.Worker, queue: :cleanup

  alias Central.Repo
  alias Teiserver.{Battle}

  @impl Oban.Worker
  @spec perform(any) :: :ok
  def perform(_) do
    Battle.list_matches(search: [
        inserted_before: Timex.shift(Timex.now(), days: -3),
        never_finished: :ok,
      ],
      limit: :infinity
    )
    |> Enum.each(&delete_match/1)

    # Remove tags from matches as the tags take up a lot of space and we don't need them long term
    # only need a 7 day window
    Battle.list_matches(search: [
        inserted_before: Timex.shift(Timex.now(), days: -14),
        inserted_after: Timex.shift(Timex.now(), days: -21)
      ],
      limit: :infinity)
    |> Enum.each(fn match ->
      duration = Timex.diff(match.finished, match.started, :second)

      cond do
        duration < 300 ->
          delete_match(match)
        true ->
          Battle.update_match(match, %{"tags" => %{}})
      end
    end)

    :ok
  end

  defp delete_match(match) do
    query = """
      DELETE FROM teiserver_battle_match_memberships
      WHERE match_id = #{match.id}
"""

    Ecto.Adapters.SQL.query(Repo, query, [])

    # Battle.list_match_memberships(search: [match_id: match.id])
    # |> Enum.each(fn membership ->
    #   Battle.delete_match_membership(membership)
    # end)

    Battle.delete_match(match)
  end
end
