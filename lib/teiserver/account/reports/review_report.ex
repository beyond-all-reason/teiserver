defmodule Teiserver.Account.ReviewReport do
  alias Central.Helpers.DatePresets
  alias Teiserver.{Account, User, Telemetry}
  alias Central.Helpers.TimexHelper

  @spec icon() :: String.t()
  def icon(), do: "fa-regular fa-champagne-glasses"

  @spec run(Plug.Conn.t(), map()) :: {map(), map()}
  def run(_conn, params) do
    params = apply_defaults(params)

    # Date range
    {start_date, end_date} =
      DatePresets.parse(
        params["date_preset"],
        params["start_date"],
        params["end_date"]
      )

    server_data = Telemetry.list_server_day_logs(search: [
      start_date: start_date,
      end_date: end_date
    ], limit: :infinity)
    |> Teiserver.Telemetry.Tasks.PersistServerMonthTask.run()
    |> Jason.encode!
    |> Jason.decode!

    match_data = Teiserver.Battle.Tasks.BreakdownMatchDataTask.perform(start_date, end_date)
    |> Jason.encode!
    |> Jason.decode!

    data = %{
      server: server_data,
      match: match_data
    }

    params = params
      |> Map.merge(%{
        "Start date" => start_date,
        "End date" => end_date,
      })

    assigns = %{
      params: params,
      presets: DatePresets.presets()
    }

    {data, assigns}
  end

  defp apply_defaults(params) do
    Map.merge(%{
      "date_preset" => "Last month",
      "start_date" => "",
      "end_date" => "",
      "mode" => ""
    }, Map.get(params, "report", %{}))
  end
end
