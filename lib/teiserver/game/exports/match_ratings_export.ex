defmodule Teiserver.Game.MatchRatingsExport do
  @moduledoc """
  Can be manually run with:
  Teiserver.Game.MatchRatingsExport.show_form(nil, %{
    "date_preset" => "All time",
    "end_date" => "",
    "rating_type" => "Large Team",
    "start_date" => ""
  })

  Teiserver.Game.MatchRatingsExport.show_form(nil, %{
    "date_preset" => "All time",
    "end_date" => "",
    "rating_type" => "Large Team",
    "start_date" => "2023-06-02"
  })
  """
  alias Teiserver.Helper.{DatePresets, TimexHelper}
  alias Teiserver.{Battle, Repo}
  alias Teiserver.Game.MatchRatingLib
  require Logger

  @id_chunk_size 10_000
  @game_chunk_size 100

  @spec icon() :: String.t()
  def icon(), do: "fa-solid fa-explosion"

  @spec permissions() :: String.t()
  def permissions(), do: "Admin"

  @spec show_form(Plug.Conn.t()) :: map()
  def show_form(_conn) do
    %{
      params: %{},
      presets: DatePresets.long_presets()
    }
  end

  def show_form(_conn, params) do
    start_time = System.system_time(:second)

    {start_date, end_date} =
      DatePresets.parse(
        params["date_preset"],
        params["start_date"],
        params["end_date"]
      )

    rating_type_id = MatchRatingLib.rating_type_name_lookup()[params["rating_type"]]

    data =
      get_data(
        start_date |> Timex.to_datetime(),
        end_date |> Timex.to_datetime(),
        rating_type_id
      )

    content_type = "application/json"
    path = "/tmp/match_ratings_export.json"
    File.write(path, Jason.encode_to_iodata!(data))

    end_time = System.system_time(:second)
    time_taken = end_time - start_time
    Logger.info("Ran #{__MODULE__} export in #{time_taken}s")

    {:file, path, "match_ratings.json", content_type}
  end

  defp get_data(start_date, end_date, rating_type_id) do
    games_per_chunk = round(@id_chunk_size / @game_chunk_size)

    calculate_match_pages(start_date, end_date, rating_type_id)
    |> Stream.with_index()
    |> Stream.map(fn {{offset, limit, total_page_count}, id_chunk_index} ->
      Logger.info("ID Chunk - #{id_chunk_index + 1}/#{total_page_count}")

      get_match_ids_in_chunk(start_date, end_date, rating_type_id, offset, limit)
      |> Stream.chunk_every(@game_chunk_size)
      |> Stream.with_index()
      |> Stream.map(fn {id_list, game_chunk_index} ->
        Logger.info("Game Chunk - #{game_chunk_index}/#{games_per_chunk}")
        get_games(id_list)
      end)
      |> Enum.to_list()
      |> List.flatten()
    end)
    |> Enum.to_list()
    |> List.flatten()
  end

  # Gets the list of ids but chunks them so we don't try to do too much at once
  defp calculate_match_pages(start_date, end_date, rating_type_id) do
    match_count =
      case get_match_count_query(start_date, end_date, rating_type_id) do
        {:ok, results} ->
          results.rows |> List.flatten() |> hd()

        {a, b} ->
          raise "ERR: #{a}, #{b}"
      end

    Logger.info("Found #{match_count} matches, #{start_date} - #{end_date}")

    page_count = ceil(match_count / @id_chunk_size)

    Range.new(0, page_count - 1)
    |> Enum.map(fn page_number ->
      {page_number * @id_chunk_size, @id_chunk_size, page_count}
    end)
  end

  defp get_match_count_query(start_date, end_date, rating_type_id) do
    query = """
      SELECT COUNT(id)
      FROM teiserver_battle_matches
      WHERE
        started >= $1
        AND finished < $2
        AND processed = true
        AND winning_team IS NOT NULL
        AND finished IS NOT NULL
        AND started IS NOT NULL
    """

    if(rating_type_id == nil) do
      Ecto.Adapters.SQL.query(Repo, query, [start_date, end_date])
    else
      query = query <> " AND rating_type_id = $3"

      Ecto.Adapters.SQL.query(Repo, query, [start_date, end_date, rating_type_id])
    end
  end

  defp get_match_ids_in_chunk(start_date, end_date, rating_type_id, offset, limit) do
    query = """
      SELECT id
      FROM teiserver_battle_matches
      WHERE
        started >= $1
        AND finished < $2
        AND rating_type_id = $3
        AND processed = true
        AND winning_team IS NOT NULL
        AND finished IS NOT NULL
        AND started IS NOT NULL
      OFFSET $4
      LIMIT $5
    """

    case Ecto.Adapters.SQL.query(Repo, query, [
           start_date,
           end_date,
           rating_type_id,
           offset,
           limit
         ]) do
      {:ok, results} ->
        List.flatten(results.rows)

      {a, b} ->
        raise "ERR: #{a}, #{b}"
    end
  end

  defp get_games(id_list) do
    Battle.list_matches(
      search: [
        id_list: id_list
      ],
      limit: :infinity,
      preload: [:members, :ratings],
      select:
        ~w(id map uuid server_uuid team_count team_size winning_team game_duration game_type started)a
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
          date: match.started |> TimexHelper.date_to_str(format: :ymd_hms),
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
          uncertainty_change: rating_log.value["uncertainty_change"]
          # old_rating:
          #   rating_log.value["rating_value"] - (rating_log.value["rating_value_change"] || 0),
          # old_skill: rating_log.value["skill"] - (rating_log.value["skill_change"] || 0),
          # old_uncertainty:
          #   rating_log.value["uncertainty"] - (rating_log.value["uncertainty_change"] || 0)
        }
    end)
  end

  defp valid_data?(members) do
    not Enum.member?(members, nil)
  end
end
