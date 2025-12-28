defmodule Teiserver.Game.MatchDataTableExport do
  @moduledoc """
  Can be manually run with:
  Teiserver.Game.MatchDataTableExport.show_form(nil, %{
    "date_preset" => "All time",
    "end_date" => "",
    "rating_type" => "Large Team",
    "start_date" => ""
  })

  Teiserver.Game.MatchDataTableExport.show_form(nil, %{
    "date_preset" => "All time",
    "end_date" => "",
    "rating_type" => "Duel",
    "start_date" => ""
  })
  """
  alias Teiserver.Helper.DatePresets
  alias Teiserver.{Battle}
  alias Teiserver.Helper.TimexHelper

  @spec icon() :: String.t()
  def icon(), do: "fa-solid fa-table"

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

    csv_data =
      Battle.list_matches(
        search: [
          started_after: start_date |> Timex.to_datetime(),
          finished_before: end_date |> Timex.to_datetime(),
          game_type: game_type,
          of_interest: true
        ],
        limit: :infinity
      )
      |> Stream.map(&make_row/1)
      |> Enum.to_list()
      |> add_csv_headings()
      |> CSV.encode()
      |> Enum.to_list()

    path = "/tmp/match_datatable.csv"
    File.write(path, csv_data)
    {:file, path, "match_datatable.csv", "text/csv"}
  end

  defp make_row(match) do
    [
      match.id,
      match.server_uuid,
      match.winning_team,
      match.team_count,
      match.team_size,
      match.passworded,
      match.game_type,
      match.founder_id,
      if(match.bots == %{}, do: "false", else: "true"),
      match.queue_id,
      match.rating_type_id,
      match.game_duration,
      TimexHelper.date_to_str(match.started, format: :ymd_hms)
    ]
  end

  defp add_csv_headings(output) do
    headings = [
      [
        "ID",
        "Server UUID",
        "Winning team",
        "Team count",
        "Team size",
        "Passworded",
        "Game type",
        "Founder ID",
        "Bots",
        "Queue ID",
        "Rating type",
        "Duration",
        "Start at"
      ]
    ]

    headings ++ output
  end
end
