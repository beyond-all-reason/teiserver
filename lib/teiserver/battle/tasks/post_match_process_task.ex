defmodule Teiserver.Battle.Tasks.PostMatchProcessTask do
  use Oban.Worker, queue: :teiserver

  alias Teiserver.{Battle, User}
  alias Central.Helpers.NumberHelper

  @impl Oban.Worker
  @spec perform(any) :: :ok
  def perform(_) do
    if ConCache.get(:application_metadata_cache, "teiserver_full_startup_completed") == true do
      Battle.list_matches(
        search: [
          ready_for_post_process: true
        ],
        preload: [:members],
        limit: :infinity
      )
      |> Enum.each(&post_process_match/1)
    end

    :ok
  end

  def perform_reprocess(match_id) do
    Battle.get_match(match_id,
      preload: [:members],
      limit: :infinity
    )
    |> post_process_match

    :ok
  end

  defp post_process_match(match) do
    skills = get_match_skill(match)

    new_data = Map.merge((match.data || %{}), %{
      "skills" => skills
    })

    use_export_data(match)
    new_data = Map.merge(new_data, extract_export_data(match))

    Battle.update_match(match, %{
      data: new_data,
      processed: true
    })
  end

  @spec get_match_skill(Battle.Match.t()) :: map()
  defp get_match_skill(%{tags: tags, members: members} = _match) do
    member_ids = members
    |> Enum.map(fn m -> m.user_id end)

    # Add the "has_played" role
    member_ids
    |> Enum.each(fn userid ->
      User.add_roles(userid, ["has_played"])
    end)

    # Get skills
    skills = tags
    |> Enum.filter(fn {k, _v} ->
      String.starts_with?(k, "game/players/") and String.ends_with?(k, "/skill")
    end)
    |> Enum.filter(fn {k, _v} ->
      userid = k
        |> String.replace("game/players/", "")
        |> String.replace("/skill", "")
        |> User.get_userid()
      Enum.member?(member_ids, userid)
    end)
    |> Enum.map(fn {_, v} ->
      v
      |> String.replace("~", "")
      |> String.replace("(", "")
      |> String.replace(")", "")
      |> String.replace("#", "")
      |> NumberHelper.float_parse
    end)

    if Enum.empty?(skills) do
      %{}
    else
      %{
        mean: Statistics.mean(skills),
        median: Statistics.median(skills),
        maximum: Enum.max(skills),
        minimum: Enum.min(skills),
        range: Enum.max(skills) - Enum.min(skills),
        stdev: Statistics.stdev(skills)
      }
    end
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

  # defp map_keys_to_integer(map, keys) do
  #   map
  #   |> Map.new(fn {k, v} ->
  #     if Enum.member?(keys, k) do
  #       {k, NumberHelper.int_parse(v)}
  #     else
  #       {k, v}
  #     end
  #   end)
  # end

  # defp map_keys_to_round(map, keys) do
  #   map
  #   |> Map.new(fn {k, v} ->
  #     if Enum.member?(keys, k) do
  #       {k, round(v)}
  #     else
  #       {k, v}
  #     end
  #   end)
  # end

  # Teiserver.Battle.Tasks.PostMatchProcessTask.perform_reprocess(37665)
end
