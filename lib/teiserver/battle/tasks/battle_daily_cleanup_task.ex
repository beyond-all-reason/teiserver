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
    # only need them for 7 days since the game, we also don't want to have to search every single game
    Battle.list_matches(search: [
        inserted_before: Timex.shift(Timex.now(), days: -7),
        inserted_after: Timex.shift(Timex.now(), days: -21)
      ],
      limit: :infinity)
    |> Enum.filter(fn match -> match.tags != %{} end)
    |> Enum.each(fn match ->
      duration = Timex.diff(match.finished, match.started, :second)

      cond do
        duration < 300 ->
          delete_match(match)
        true ->
          Battle.update_match(match, %{"tags" => %{}})
      end
    end)

    delete_old_matches()

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

  defp delete_old_matches() do
    ids = Battle.list_matches(search: [
        inserted_before: Timex.shift(Timex.now(), days: -95)
      ],
      search: [:id],
      limit: :infinity
    )
    |> Enum.map(fn %{id: id} -> id end)
    |> Enum.join(",")

    query = """
      DELETE FROM teiserver_battle_match_memberships
      WHERE match_id IN #{ids}
"""
    Ecto.Adapters.SQL.query(Repo, query, [])

    query = """
      DELETE FROM teiserver_battle_matches
      WHERE id IN #{ids}
"""
    Ecto.Adapters.SQL.query(Repo, query, [])
  end
end
