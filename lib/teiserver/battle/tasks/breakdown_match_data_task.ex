defmodule Teiserver.Battle.Tasks.BreakdownMatchDataTask do
  @doc """
  Provides aggregate data about matches which took place within a given timeframe
  """
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
      totals: get_subset_data(matches, nil),
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

  defp get_subset_data(matches, nil) do
    matches
    |> Stream.map(fn m -> Map.drop(m, ~w(tags)a) end)
    |> do_get_subset_data
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
    |> Map.new
    # |> Enum.map(fn {k, v} -> {k, v} end)
    # |> Enum.sort_by(fn {_, v} -> v end, &>=/2)

    mean_skill = matches
    |> Stream.filter(fn m -> m.data["skills"] != %{} end)
    |> Stream.map(fn m -> m.data["skills"]["mean"] |> round end)
    |> Enum.frequencies()
    |> Map.new
    # |> Enum.map(fn {k, v} -> {k, v} end)
    # |> Enum.sort_by(fn {k, _} -> k end, &>=/2)

    duration = matches
    |> Stream.map(fn match ->
      d = Timex.diff(match.finished, match.started, :second)
      :math.floor(d / 300) * 5
      |> round
    end)
    |> Enum.frequencies()
    |> Map.new

    total_duration = matches
    |> Stream.map(fn match ->
      Timex.diff(match.finished, match.started, :second)
    end)
    |> Enum.sum

    matches_per_hour = matches
    |> Stream.map(fn match -> match.started.hour end)
    |> Enum.frequencies()
    |> Map.new
    # |> Enum.map(fn {k, v} -> {k, v} end)
    # |> Enum.sort_by(fn {k, _} -> k end, &>=/2)

    team_sizes = matches
    |> Stream.map(fn match -> match.team_size end)
    |> Enum.frequencies()
    |> Map.new

    %{
      maps: maps,
      mean_skill: mean_skill,
      duration: duration,
      matches_per_hour: matches_per_hour,
      team_sizes: team_sizes,
      aggregate: %{
        total_count: Enum.count(matches),
        total_duration_seconds: total_duration,
        mean_duration_seconds: total_duration/max(Enum.count(matches), 1) |> round
      }
    }
  end
end
