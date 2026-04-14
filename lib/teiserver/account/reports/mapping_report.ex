defmodule Teiserver.Game.MappingReport do
  @moduledoc false
  alias Teiserver.Battle
  alias Teiserver.Helper.DatePresets

  @spec icon() :: String.t()
  def icon, do: "fa-solid fa-map"

  @spec permissions() :: String.t()
  def permissions, do: "Admin"

  @threshold 10

  @spec run(Plug.Conn.t(), map()) :: map()
  def run(_conn, params) do
    params = apply_defaults(params)

    # Date range
    {start_date, end_date} =
      DatePresets.parse(
        params["date_preset"],
        params["start_date"],
        params["end_date"]
      )

    types =
      params
      |> Map.get("types", ["Duel", "Team", "Small Team", "Large Team"])
      |> Enum.reject(&(&1 == "false"))

    rated_filter =
      case params["rated"] do
        "Rated" -> true
        "Unrated" -> false
        _other -> nil
      end

    min_duration =
      case params["min_duration"] do
        "" -> nil
        val -> String.to_integer(val)
      end

    max_duration =
      case params["max_duration"] do
        "" -> nil
        val -> String.to_integer(val)
      end

    data =
      Battle.list_matches(
        search: [
          started_after: start_date |> Timex.to_datetime(),
          started_before: end_date |> Timex.to_datetime(),
          game_type_in: types,
          rated: rated_filter,
          duration_greater_than: min_duration,
          duration_less_than: max_duration,
          of_interest: true,
          has_winning_team: true
        ],
        limit: :infinity
      )
      |> Enum.group_by(fn %{map: map} -> map end)
      |> Enum.reject(fn {_map, matches} -> Enum.count(matches) < @threshold end)
      |> Enum.map(fn {map, matches} ->
        count = Enum.count(matches)

        team1_wins =
          matches
          |> Enum.count(fn m -> m.winning_team == 0 end)

        team2_wins =
          matches
          |> Enum.count(fn m -> m.winning_team == 1 end)

        team1_favour = team1_wins / count - team2_wins / count

        avg_duration =
          matches
          |> Enum.map(fn m -> m.game_duration end)
          |> Enum.sum()
          |> Kernel.div(count)

        {map,
         %{
           count: count,
           team1_favour: team1_favour,
           avg_duration: avg_duration
         }}
      end)
      |> Enum.sort_by(fn {_map, stats} -> stats.count end, &>=/2)

    total_total =
      data
      |> Enum.map(fn {_map, stats} -> stats.count end)
      |> Enum.sum()

    %{
      params: params,
      presets: DatePresets.long_ranges(),
      total_total: total_total,
      data: data
    }
  end

  defp apply_defaults(params) do
    Map.merge(
      %{
        "date_preset" => "This month",
        "start_date" => "",
        "end_date" => "",
        "mode" => "",
        "types" => ["Duel", "Team", "Small Team", "Large Team"],
        "min_duration" => "",
        "max_duration" => "",
        "rated" => "all"
      },
      Map.get(params, "report", %{})
    )
  end
end
