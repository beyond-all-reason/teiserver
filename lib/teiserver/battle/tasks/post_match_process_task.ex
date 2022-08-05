defmodule Teiserver.Battle.Tasks.PostMatchProcessTask do
  use Oban.Worker, queue: :teiserver

  alias Teiserver.{Battle, User}
  alias Central.Helpers.NumberHelper
  alias Central.Config
  # alias Teiserver.Data.Types, as: T

  @impl Oban.Worker
  @spec perform(any) :: :ok
  def perform(_) do
    if Central.cache_get(:application_metadata_cache, "teiserver_full_startup_completed") == true do
      if Config.get_site_config_cache("system.Process matches") do
        Battle.list_matches(
          search: [
            ready_for_post_process: true
          ],
          preload: [:members],
          limit: :infinity
        )
        |> Enum.each(&post_process_match/1)
      end
    end

    :ok
  end

  @spec perform_reprocess(non_neg_integer()) :: :ok
  def perform_reprocess(match_id) do
    Battle.get_match(match_id,
      preload: [:members],
      limit: :infinity
    )
    |> post_process_match

    :ok
  end

  defp post_process_match(match) do
    new_data = Map.merge((match.data || %{}), %{
      "player_count" => Enum.count(match.members)
    })

    use_export_data(match)
    new_data = Map.merge(new_data, extract_export_data(match))

    {:ok, match} = Battle.update_match(match, %{
      data: new_data,
      processed: true
    })

    # We pass match.id to ensure we re-query the match correctly
    Teiserver.Game.MatchRatingLib.rate_match(match.id)
  end

  defp use_export_data(%{data: %{"export_data" => export_data}} = match) do
    win_map = export_data["players"]
    |> Map.new(fn stats -> {stats["name"], stats["win"] == 1} end)

    winning_team = Battle.list_match_memberships(search: [match_id: match.id])
    |> Enum.map(fn m ->
      username = User.get_username(m.user_id)
      win = Map.get(win_map, username, false)

      stats = export_data["teamStats"]
        |> Map.get(username, %{})
        |> Map.drop(~w(allyTeam frameNb))
        |> Map.new(fn {k, v} ->
          {k,
            v
              |> NumberHelper.int_parse()
              |> round
          }
        end)

      Battle.update_match_membership(m, %{
        win: win,
        stats: stats
      })

      {m.team_id, win}
    end)
    |> Enum.filter(fn {_teamid, win} -> win == true end)
    |> hd_or_x({nil, nil})
    |> elem(0)

    Battle.update_match(match, %{winning_team: winning_team})
  end
  defp use_export_data(_), do: []

  defp extract_export_data(%{data: %{"export_data" => _export_data}} = _match) do
    %{}
  end
  defp extract_export_data(_), do: %{}

  defp hd_or_x([], x), do: x
  defp hd_or_x([x | _], _x), do: x
end
