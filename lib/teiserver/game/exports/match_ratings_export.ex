defmodule Teiserver.Game.MatchRatingsExport do
  @moduledoc """
  Can be manually run with:
  Teiserver.Game.MatchRatingsExport.show_form(nil, %{
    "date_preset" => "All time",
    "end_date" => "",
    "rating_type" => "Team",
    "start_date" => ""
  })
  """
  alias Central.Helpers.DatePresets
  alias Teiserver.{Battle}

  @spec icon() :: String.t()
  def icon(), do: "fa-regular fa-swords"

  @spec permissions() :: String.t()
  def permissions(), do: "teiserver.admin"

  @spec show_form(Plug.Conn.t()) :: map()
  def show_form(_conn) do
    %{
      params: %{},
      presets: DatePresets.long_presets()
    }
  end

  def show_form(_conn, params) do
    {start_date, end_date} =
      DatePresets.parse(
        params["date_preset"],
        params["start_date"],
        params["end_date"]
      )

    game_type =
      case params["rating_type"] do
        "All" -> nil
        t -> t
      end

    game_ids =
      Battle.list_matches(
        search: [
          started_after: start_date |> Timex.to_datetime(),
          finished_before: end_date |> Timex.to_datetime(),
          game_type: game_type,
          of_interest: true
        ],
        limit: :infinity,
        # limit: 5,
        select: [:id]
      )
      |> Stream.map(fn %{id: id} -> id end)
      |> Enum.to_list()

    data =
      game_ids
      |> Stream.chunk_every(100)
      |> Stream.map(fn id_list ->
        get_games(id_list)
      end)
      |> Enum.to_list()
      |> List.flatten()

    content_type = "application/json"
    path = "/tmp/match_ratings_export_123.json"
    File.write(path, Jason.encode_to_iodata!(data))
    {:file, path, "match_ratings.json", content_type}
  end

  defp get_games(id_list) do
    Battle.list_matches(
      search: [
        id_list: id_list
      ],
      limit: :infinity,
      preload: [:members, :ratings],
      select:
        ~w(id map uuid server_uuid team_count team_size winning_team game_duration game_type)a
    )
    |> Stream.filter(fn match ->
      cond do
        Enum.empty?(match.ratings) -> false
        true -> true
      end
    end)
    |> Stream.map(fn match ->
      members_lookup =
        match.members
        |> Map.new(fn m -> {m.user_id, m} end)

      ratings_and_members =
        match.ratings
        |> Enum.map(fn r ->
          {r, members_lookup[r.user_id]}
        end)

      members_data = expand_members(ratings_and_members)

      if valid_data?(members_data) do
        %{
          id: match.id,
          map: match.map,
          match_uuid: match.uuid,
          server_uuid: match.server_uuid,
          team_count: match.team_count,
          team_size: match.team_size,
          winning_team: match.winning_team,
          game_duration: match.game_duration,
          game_type: match.game_type,
          members: members_data
        }
      end
    end)
    |> Enum.reject(&(&1 == nil))
    |> Enum.to_list()
  end

  defp expand_members(rating_list) do
    rating_list
    |> Enum.map(fn
      {nil, _} ->
        nil

      {_, nil} ->
        nil

      {rating_log, member} ->
        %{
          user_id: rating_log.user_id,
          party_id: rating_log.party_id,
          team_id: member.team_id,
          win: member.win,
          left_after: member.left_after,
          new_rating: rating_log.value["rating_value"],
          new_skill: rating_log.value["skill"],
          new_uncertainty: rating_log.value["uncertainty"],
          rating_change: rating_log.value["rating_change"],
          skill_change: rating_log.value["skill_change"],
          uncertainty_change: rating_log.value["uncertainty_change"],
          old_rating:
            rating_log.value["rating_value"] - (rating_log.value["rating_value_change"] || 0),
          old_skill: rating_log.value["skill"] - (rating_log.value["skill_change"] || 0),
          old_uncertainty:
            rating_log.value["uncertainty"] - (rating_log.value["uncertainty_change"] || 0)
        }
    end)
  end

  defp valid_data?(members) do
    not Enum.member?(members, nil)
  end
end
