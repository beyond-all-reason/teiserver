defmodule Teiserver.Game.MatchRatingsExport do
  @moduledoc """

  """
  alias Central.Helpers.DatePresets
  alias Teiserver.{Battle}

  @spec icon() :: String.t()
  def icon(), do: "fa-regular fa-swords"

  @spec permissions() :: String.t()
  def permissions(), do: "teiserver.admin"

  @spec show_form(Plug.Conn.t()) :: map()
  def show_form(conn) do
    %{
      params: %{},
      presets: DatePresets.long_presets
    }
  end

  def show_form(conn, params) do
    {start_date, end_date} =
      DatePresets.parse(
        params["date_preset"],
        params["start_date"],
        params["end_date"]
      )

    game_type = case params["rating_type"] do
      "All" -> nil
      t -> t
    end

    game_ids = Battle.list_matches(
      search: [
        started_after: start_date |> Timex.to_datetime,
        finished_before: end_date |> Timex.to_datetime,
        game_type: game_type,
        of_interest: true
      ],
      # limit: :infinity,
      limit: 5,
      select: [:id]
    )
      |> Enum.map(fn %{id: id} -> id end)

    data = game_ids
      |> Stream.chunk_every(50)
      |> Enum.map(fn id_list ->
        get_games(id_list)
      end)
      |> List.flatten

    {:raw, data |> Jason.encode!}
  end

  defp get_games(id_list) do
    Battle.list_matches(
      search: [
        id_list: id_list
      ],
      # preload: [:members, :ratings]
      preload: [:ratings]
    )
    |> Enum.map(fn match ->
      %{
        id: match.id,
        map: match.map,
        match_uuid: match.uuid,
        server_uuid: match.server_uuid,
        team_count: match.team_count,
        team_size: match.team_size,
        game_duration: match.game_duration,
        ratings: convert_ratings(match.ratings)
      }
    end)
  end

  def convert_ratings(rating_list) do
    rating_list
    |> Enum.map(fn log ->
      %{
        user_id: log.user_id,
        party_id: log.party_id,

        new_rating: log.value["rating_value"],
        new_skill: log.value["skill"],
        new_uncertainty: log.value["uncertainty"],

        rating_change: log.value["rating_change"],
        skill_change: log.value["skill_change"],
        uncertainty_change: log.value["uncertainty_change"],

        old_rating: log.value["rating_value"] - (log.value["rating_change"] || 0),
        old_skill: log.value["skill"] - (log.value["skill_change"] || 0),
        old_uncertainty: log.value["uncertainty"] - (log.value["uncertainty_change"] || 0)
      }
    end)
  end
end
