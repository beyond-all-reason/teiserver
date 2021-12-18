defmodule Teiserver.Battle.Tasks.BreakdownMatchDataTask do
  alias Teiserver.Battle

  @spec perform(%Date{}) :: map()
  @spec perform(%Date{}, %Date{}) :: map()
  def perform(start_date) do
    perform(start_date, Timex.shift(start_date, days: 1))
  end

  def perform(start_date, end_date) do
    matches = get_matches(start_date, end_date)
    |> Stream.filter(fn match ->
      Timex.diff(match.finished, match.started, :second) >= 300
    end)

    %{
      duel: get_subset_data(matches, "Duel"),
      team: get_subset_data(matches, "Team"),
      ffa: get_subset_data(matches, "FFA"),
      scavenger: get_subset_data(matches, "Scavengers"),
      chicken: get_subset_data(matches, "Chicken"),
    }
  end


  @spec get_matches(%Date{}, %Date{}) :: [map()]
  defp get_matches(start_date, end_date) do
    start_date = Timex.to_datetime(start_date)
    end_date = Timex.to_datetime(end_date)

    Battle.list_matches(
      search: [
        inserted_after: start_date,
        inserted_before: end_date,
        of_interest: true
      ],
      limit: :infinity
    )
  end

  defp get_subset_data(matches, game_type) do
    matches
    |> Stream.filter(fn m -> m.game_type == game_type end)
    |> Stream.map(fn m -> Map.drop(m, ~w(tags)a) end)
    |> do_get_subset_data
  end

  defp do_get_subset_data(matches) do
    maps = matches
    |> Stream.map(fn m -> m.map end)
    |> Enum.frequencies()
    |> Enum.map(fn {k, v} -> {k, v} end)
    |> Enum.sort_by(fn {_, v} -> v end, &>=/2)

    mean_skill = matches
    |> Stream.map(fn m -> m.data["skills"]["mean"] |> round end)
    |> Enum.frequencies()
    |> Enum.map(fn {k, v} -> {k, v} end)
    |> Enum.sort_by(fn {k, _} -> k end, &>=/2)

    duration = matches
    |> Stream.map(fn match ->
      d = Timex.diff(match.finished, match.started, :second)
      :math.floor(d / 300) * 5
      |> round
    end)
    |> Enum.frequencies()
    |> Enum.map(fn {k, v} -> {k, v} end)
    |> Enum.sort_by(fn {k, _} -> k end, &>=/2)

    %{
      maps: maps,
      mean_skill: mean_skill,
      duration: duration
    }
  end

#   %Teiserver.Battle.Match{
#   __meta__: #Ecto.Schema.Metadata<:loaded, "teiserver_battle_matches">,
#   bots: %{},
#   data: %{
#     "skills" => %{
#       "maximum" => 26.03,
#       "mean" => 17.02,
#       "median" => 17.02,
#       "minimum" => 8.01,
#       "range" => 18.020000000000003,
#       "stdev" => 9.01
#     }
#   },
#   finished: ~U[2021-12-15 18:35:25Z],
#   founder: #Ecto.Association.NotLoaded<association :founder is not loaded>,
#   founder_id: 3411,
#   game_type: "Duel",
#   id: 25353,
#   inserted_at: ~N[2021-12-15 18:07:05],
#   map: "Altair_Crossing_V4",
#   members: #Ecto.Association.NotLoaded<association :members is not loaded>,
#   passworded: false,
#   started: ~U[2021-12-15 18:07:05Z],
#   team_count: 2,
#   team_size: 1,
#   updated_at: ~N[2021-12-15 18:36:00],
#   uuid: "5f0cff5c-5dce-11ec-bfc7-00163ce514e4"
# }

end
