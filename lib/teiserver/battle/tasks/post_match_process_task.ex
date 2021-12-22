defmodule Teiserver.Battle.Tasks.PostMatchProcessTask do
  use Oban.Worker, queue: :teiserver

  alias Teiserver.{Battle, User}
  alias Central.Helpers.NumberHelper

  @impl Oban.Worker
  @spec perform(any) :: :ok
  def perform(_) do
    Battle.list_matches(
      search: [
        ready_for_post_process: true
      ],
      preload: [:members],
      limit: :infinity
    )
    |> Enum.each(&post_process_match/1)

    :ok
  end

  defp post_process_match(match) do
    skills = get_match_skill(match)

    new_data = %{
      skills: skills
    }

    Battle.update_match(match, %{
      data: new_data
    })
  end

  @spec get_match_skill(Battle.Match.t()) :: map()
  defp get_match_skill(%{tags: tags, members: members} = _match) do
    member_ids = members
    |> Enum.map(fn m -> m.user_id end)

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
end
