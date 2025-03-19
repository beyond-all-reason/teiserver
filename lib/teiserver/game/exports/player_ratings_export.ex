defmodule Teiserver.Game.PlayerRatingsExport do
  @moduledoc """
  Can be manually run with:
  Teiserver.Game.PlayerRatingsExport.show_form(nil, %{
    "date_preset" => "All time",
    "end_date" => "",
    "rating_type" => "Large Team",
    "start_date" => ""
  })

  Teiserver.Game.PlayerRatingsExport.show_form(nil, %{
    "date_preset" => "All time",
    "end_date" => "",
    "rating_type" => "Duel",
    "start_date" => ""
  })
  """
  alias Teiserver.Account
  alias Teiserver.Game.MatchRatingLib
  require Logger

  @spec icon() :: String.t()
  def icon(), do: "fa-solid fa-user-shield"

  @spec permissions() :: String.t()
  def permissions(), do: "teiserver.admin"

  @spec show_form(Plug.Conn.t()) :: map()
  def show_form(_conn) do
    %{
      params: %{}
    }
  end

  def show_form(_conn, params) do
    start_time = System.system_time(:second)

    rating_type_id = MatchRatingLib.rating_type_name_lookup()[params["rating_type"]]
    season = MatchRatingLib.active_season()

    ratings =
      Account.list_ratings(
        search: [
          rating_type_id: rating_type_id,
          season: season
        ],
        select:
          ~w(user_id rating_type_id rating_value skill uncertainty leaderboard_rating last_updated)a,
        limit: :infinity
      )
      |> Enum.map(fn rating ->
        Map.take(
          rating,
          ~w(user_id rating_type_id rating_value skill uncertainty leaderboard_rating last_updated)a
        )
      end)

    Logger.info("Found #{Enum.count(ratings)} ratings")

    content_type = "application/json"
    path = "/tmp/player_ratings_export.json"
    File.write(path, Jason.encode_to_iodata!(ratings))

    end_time = System.system_time(:second)
    time_taken = end_time - start_time
    Logger.info("Ran #{__MODULE__} export in #{time_taken}s")

    {:file, path, "player_ratings.json", content_type}
  end
end
