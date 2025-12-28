defmodule Teiserver.Battle.Tasks.PostMatchProcessTask do
  @moduledoc """
  Used to process data about a match after it has ended.
  """
  use Oban.Worker, queue: :teiserver

  alias Teiserver.{Account, Battle, Coordinator}
  alias Teiserver.Battle.MatchMembershipLib
  alias Teiserver.Helper.NumberHelper
  alias Teiserver.Config
  alias Teiserver.Repo
  # alias Teiserver.Data.Types, as: T

  @impl Oban.Worker
  @spec perform(any) :: :ok
  def perform(_) do
    if Teiserver.cache_get(:application_metadata_cache, "teiserver_full_startup_completed") ==
         true do
      if Config.get_site_config_cache("system.Process matches") do
        Battle.list_matches(
          search: [
            ready_for_post_process: true
          ],
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
      preload: [],
      limit: 1
    )
    |> post_process_match()

    :ok
  end

  defp post_process_match(match) do
    data_player_ids =
      (match.data["export_data"]["teamStats"] || %{})
      |> Map.keys()
      |> Enum.map(fn name ->
        Account.get_userid_from_name(name)
      end)

    # Now delete match memberships from those not meant to be present
    MatchMembershipLib.get_match_memberships()
    |> MatchMembershipLib.search(
      match_id: match.id,
      user_id_not_in: data_player_ids
    )
    |> Repo.delete_all()

    # Now re-get the match
    match =
      Battle.get_match(match.id,
        preload: [:members],
        limit: 1
      )

    new_data =
      Map.merge(match.data || %{}, %{
        "player_count" => Enum.count(match.members)
      })

    use_export_data(match)
    new_data = Map.merge(new_data, extract_export_data(match))

    {:ok, match} =
      Battle.update_match(match, %{
        data: new_data,
        processed: true
      })

    # We pass match.id to ensure we re-query the match correctly
    Teiserver.Game.MatchRatingLib.rate_match(match.id)

    # Tell the host to re-rate some players
    usernames =
      match.members
      |> Enum.map_join(" ", fn m -> Account.get_username(m.user_id) end)

    msg = "updateSkill #{usernames}"
    Coordinator.send_to_user(match.founder_id, msg)
  end

  defp use_export_data(%{data: %{"export_data" => export_data}} = match) do
    win_map =
      export_data["players"]
      |> Map.new(fn stats -> {stats["accountId"], stats["win"] == 1} end)

    # If users renamed after the start of the match but before it gets processed they couldn't be matched to their teamStats
    name_map =
      export_data["players"]
      |> Map.new(fn stats -> {stats["accountId"], stats["name"]} end)

    host_game_duration = max(export_data["gameDuration"], 1)
    memberships = Battle.list_match_memberships(search: [match_id: match.id])

    winning_team =
      memberships
      |> Enum.map(fn m ->
        win = Map.get(win_map, to_string(m.user_id), false)
        name = Map.get(name_map, to_string(m.user_id), Account.get_username(m.user_id))

        stats =
          export_data["teamStats"]
          |> Map.get(name, %{})
          |> Map.drop(~w(allyTeam frameNb))
          |> Map.new(fn {k, v} ->
            {k,
             v
             |> NumberHelper.int_parse()
             |> round()}
          end)

        player_data =
          export_data["players"]
          |> Enum.filter(fn p -> p["accountId"] == to_string(m.user_id) end)

        case player_data do
          [d] ->
            left_after =
              case d["loseTime"] do
                "" -> host_game_duration
                v -> v
              end

            Battle.update_match_membership(m, %{
              left_after: left_after,
              win: win,
              stats: stats
            })

          _ ->
            Battle.update_match_membership(m, %{
              win: win,
              stats: stats
            })
        end

        {m.team_id, win}
      end)
      |> Enum.filter(fn {_teamid, win} -> win == true end)
      |> hd_or_x({nil, nil})
      |> elem(0)

    Battle.update_match(match, %{
      winning_team: winning_team,
      game_duration: host_game_duration,
      game_id: export_data["gameId"]
    })

    memberships
    |> Enum.map(fn m ->
      Teiserver.Account.RecacheUserStatsTask.match_processed(match, m.user_id)
    end)
  end

  defp use_export_data(_), do: []

  defp extract_export_data(%{data: %{"export_data" => _export_data}} = _match) do
    %{}
  end

  defp extract_export_data(_), do: %{}

  defp hd_or_x([], x), do: x
  defp hd_or_x([x | _], _x), do: x
end
