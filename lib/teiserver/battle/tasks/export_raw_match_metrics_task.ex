defmodule Teiserver.Battle.ExportRawMatchMetricsTask do
  alias Teiserver.Battle
  alias Teiserver.Helper.{DatePresets}

  def perform(params) do
    {start_date, end_date} =
      DatePresets.parse(
        params["date_preset"],
        params["start_date"],
        params["end_date"]
      )

    start_date = Timex.to_datetime(start_date)
    end_date = Timex.to_datetime(end_date)

    Battle.list_matches(
      search: [
        started_after: start_date,
        started_before: end_date,
        processed: true
      ],
      preload: [
        :members
      ],
      limit: :infinity,
      order: "Oldest first"
    )
    |> do_output(params)
  end

  defp do_output(data, _params) do
    data
    |> Stream.filter(fn match ->
      match.game_type in ["Small Team", "Big Team"]
    end)
    |> Stream.map(fn match ->
      members =
        match.members
        |> Enum.map(fn m -> Map.take(m, ~w(user_id team_id)a) end)

      match
      |> Map.take(
        ~w(uuid map data team_count team_size passworded game_type founder_id bots started finished)a
      )
      |> Map.put(:members, members)
    end)
    |> Enum.to_list()
    |> Jason.encode!()
  end
end
