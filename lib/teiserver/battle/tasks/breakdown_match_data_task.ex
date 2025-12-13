defmodule Teiserver.Battle.Tasks.BreakdownMatchDataTask do
  @doc """
  Provides aggregate data about matches which took place within a given timeframe
  """
  alias Teiserver.Battle

  @spec perform(Date.t()) :: map()
  @spec perform(Date.t(), Date.t()) :: map()
  def perform(start_date) do
    perform(start_date, Timex.shift(start_date, days: 1))
  end

  def perform(start_date, end_date) do
    matches =
      get_matches(start_date, end_date)
      |> Stream.filter(fn match ->
        Timex.diff(match.finished, match.started, :second) >= 300
      end)

    %{
      duel: get_subset_data(matches, game_type: "Duel"),
      small_team: get_subset_data(matches, game_type: "Small Team"),
      large_team: get_subset_data(matches, game_type: "Large Team"),
      ffa: get_subset_data(matches, game_type: "FFA"),
      team_ffa: get_subset_data(matches, game_type: "Team FFA"),
      scavengers: get_subset_data(matches, game_type: "Scavengers"),
      raptors: get_subset_data(matches, game_type: "Raptors"),
      bots: get_subset_data(matches, game_type: "Bots"),
      totals: get_subset_data(matches)
    }
  end

  @spec get_matches(Date.t(), Date.t()) :: [map()]
  defp get_matches(start_date, end_date) do
    start_date = Timex.to_datetime(start_date)
    end_date = Timex.to_datetime(end_date)

    Battle.list_matches(
      search: [
        inserted_after: start_date,
        inserted_before: end_date,
        of_interest: true
      ],
      preload: [:members],
      limit: :infinity
    )
  end

  defp get_subset_data(matches, opts \\ []) do
    matches
    |> Stream.filter(fn m ->
      if opts[:game_type] do
        m.game_type == opts[:game_type]
      else
        true
      end
    end)
    |> Stream.map(fn m -> Map.drop(m, ~w(tags)a) end)
    |> do_get_subset_data(opts)
  end

  defp do_get_subset_data(matches, _opts) do
    maps =
      matches
      |> Stream.map(fn m -> m.map end)
      |> Enum.frequencies()
      |> Map.new()

    duration =
      matches
      |> Stream.map(fn match ->
        d = Timex.diff(match.finished, match.started, :second)

        (:math.floor(d / 300) * 5)
        |> round()
      end)
      |> Enum.frequencies()
      |> Map.new()

    total_duration =
      matches
      |> Stream.map(fn match ->
        Timex.diff(match.finished, match.started, :second)
      end)
      |> Enum.sum()

    matches_per_hour =
      matches
      |> Stream.map(fn match -> match.started.hour end)
      |> Enum.frequencies()
      |> Map.new()

    team_sizes =
      matches
      |> Stream.map(fn match -> match.team_size end)
      |> Enum.frequencies()
      |> Map.new()

    # TODO: change this to be based on data["player_count"]
    # we were not tracking player count as a separate number so can't be done yet
    weighted_count =
      matches
      |> Enum.map(fn m -> Enum.count(m.members) end)
      |> Enum.sum()

    %{
      maps: maps,
      duration: duration,
      matches_per_hour: matches_per_hour,
      team_sizes: team_sizes,
      aggregate: %{
        total_count: Enum.count(matches),
        weighted_count: weighted_count,
        total_duration_seconds: total_duration,
        mean_duration_seconds: (total_duration / max(Enum.count(matches), 1)) |> round()
      }
    }
  end
end
