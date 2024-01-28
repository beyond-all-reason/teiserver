defmodule Barserver.Game.RatingLogsExport do
  @moduledoc """
  Can be manually run with:
  Barserver.Game.RatingLogsExport.show_form(nil, %{
    "date_preset" => "All time",
    "end_date" => "",
    "rating_type" => "Team",
    "start_date" => ""
  })

  Barserver.Game.RatingLogsExport.show_form(nil, %{
    "date_preset" => "All time",
    "end_date" => "",
    "rating_type" => "Duel",
    "start_date" => ""
  })
  """
  alias Barserver.Helper.{DatePresets}
  alias Barserver.Game
  alias Barserver.Game.MatchRatingLib
  require Logger

  @spec icon() :: String.t()
  def icon(), do: "fa-regular fa-rectangle-vertical-history"

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
    start_time = System.system_time(:second)

    {start_date, end_date} =
      DatePresets.parse(
        params["date_preset"],
        params["start_date"],
        params["end_date"]
      )

    rating_type_id = MatchRatingLib.rating_type_name_lookup()[params["rating_type"]]

    logs =
      Game.list_rating_logs(
        search: [
          rating_type_id: rating_type_id,
          inserted_after: Timex.to_datetime(start_date),
          inserted_before: Timex.to_datetime(end_date)
        ],
        select: ~w(user_id rating_type_id match_id party_id value inserted_at)a,
        limit: :infinity
      )
      |> Enum.map(fn rating ->
        Map.take(
          rating,
          ~w(user_id rating_type_id match_id party_id value inserted_at)a
        )
      end)

    Logger.info("Found #{Enum.count(logs)} rating logs")

    content_type = "application/json"
    path = "/tmp/rating_logs_export.json"
    File.write(path, Jason.encode_to_iodata!(logs))

    end_time = System.system_time(:second)
    time_taken = end_time - start_time
    Logger.info("Ran #{__MODULE__} export in #{time_taken}s")

    {:file, path, "rating_logs_export.json", content_type}
  end
end
