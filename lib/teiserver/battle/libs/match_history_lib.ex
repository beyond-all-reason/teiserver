defmodule Teiserver.Battle.MatchHistoryLib do
  @moduledoc false

  alias Teiserver.Repo

  # Get your win rate for this map for matches played on this date or earlier (limit 50)
  # Includes unrated games but not bot games
  def get_win_rate_stats(user_id, match_map, match_started_date) do
    query = """
    select tbmm.win from  teiserver_battle_match_memberships tbmm
    inner join teiserver_battle_matches tbm
    on tbm.id  = tbmm.match_id
    and tbm.map = $1
    and tbm.bots::jsonb = '{}'::jsonb
    and tbm.started  <= $2
    and tbmm.user_id  = $3
    order by tbm.started desc
    limit 50
    """

    results = Ecto.Adapters.SQL.query!(Repo, query, [match_map, match_started_date, user_id])

    win_list = results.rows |> List.flatten()

    match_count = length(win_list)

    if(match_count == 0) do
      %{
        win_rate: 0,
        match_count: 0
      }
    else
      win_count = Enum.filter(win_list, fn x -> x == true end) |> length

      %{
        win_rate: win_count / match_count,
        match_count: match_count
      }
    end
  end
end
