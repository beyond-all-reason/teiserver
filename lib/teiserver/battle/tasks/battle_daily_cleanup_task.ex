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
        select: [:id],
        limit: :infinity
    )
      |> Enum.map(fn %{id: id} -> id end)
      |> Enum.join(",")
      |> delete_matches()

    # Remove tags from matches as the tags take up a lot of space and we don't need them long term
    # only need them for 7 days since the game, we also don't want to have to search every single game
    matches = Battle.list_matches(search: [
        inserted_before: Timex.shift(Timex.now(), days: -7),
        inserted_after: Timex.shift(Timex.now(), days: -21)
      ],
      limit: :infinity
    )
      |> Enum.filter(fn match -> match.tags != %{} end)

    # Delete short matches
    matches
      |> Enum.filter(fn match ->
        duration = Timex.diff(match.finished, match.started, :second)
        duration < Application.get_env(:central, Teiserver)[:retention][:battle_minimum_seconds]
      end)
      |> Enum.map(fn %{id: id} -> id end)
      |> Enum.join(",")
      |> delete_matches()

    # Wipe tags of remaining matches
    matches
      |> Enum.map(fn %{id: id} -> id end)
      |> Enum.join(",")
      |> remove_tags

    # Finally, delete the older matches
    delete_old_matches()

    :ok
  end

  defp delete_old_matches() do
    days = Application.get_env(:central, Teiserver)[:retention][:battle_match]

    ids = Battle.list_matches(search: [
        inserted_before: Timex.shift(Timex.now(), days: -days)
      ],
      search: [:id],
      limit: :infinity
    )
    |> Enum.map(fn %{id: id} -> id end)
    |> Enum.join(",")

    delete_matches(ids)
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

  defp remove_tags(""), do: :ok
  defp remove_tags(ids) do
    query = """
      UPDATE teiserver_battle_matches SET tags = '{}'
      WHERE id IN (#{ids})
"""
    Ecto.Adapters.SQL.query(Repo, query, [])
  end
end
