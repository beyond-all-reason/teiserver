defmodule Teiserver.Game.MappingReport do
  alias Teiserver.Helper.DatePresets
  alias Teiserver.{Battle}

  @spec icon() :: String.t()
  def icon(), do: "fa-solid fa-map"

  @spec permissions() :: String.t()
  def permissions(), do: "Admin"

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

    data =
      Battle.list_matches(
        search: [
          started_after: start_date |> Timex.to_datetime(),
          started_before: end_date |> Timex.to_datetime(),
          game_type_in: ["Duel", "Small Team", "Large Team"],
          of_interest: true,
          has_winning_team: true
        ],
        limit: :infinity
      )
      |> Enum.group_by(fn %{map: map} -> map end)
      |> Enum.reject(fn {_, matches} -> Enum.count(matches) < @threshold end)
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
      |> Enum.sort_by(fn {_, stats} -> stats.count end, &>=/2)

    total_total =
      data
      |> Enum.map(fn {_, stats} -> stats.count end)
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
        "mode" => ""
      },
      Map.get(params, "report", %{})
    )
  end
end
