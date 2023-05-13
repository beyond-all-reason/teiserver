defmodule Teiserver.Account.ReviewReport do
  alias Central.Helpers.DatePresets
  alias Teiserver.{Telemetry}

  @spec icon() :: String.t()
  def icon(), do: "fa-regular fa-champagne-glasses"

  @spec permissions() :: String.t()
  def permissions(), do: "Admin"

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

    server_data =
      Telemetry.list_server_day_logs(
        search: [
          start_date: start_date,
          end_date: end_date
        ],
        limit: :infinity
      )
      |> Teiserver.Telemetry.ServerDayLogLib.aggregate_day_logs()
      |> Jason.encode!()
      |> Jason.decode!()

    days = Timex.diff(end_date, start_date, :days)
    past_end_date = start_date
    past_start_date = Timex.shift(past_end_date, days: -days)

    past_server_data =
      Telemetry.list_server_day_logs(
        search: [
          start_date: past_start_date,
          end_date: past_end_date
        ],
        limit: :infinity
      )
      |> Teiserver.Telemetry.ServerDayLogLib.aggregate_day_logs()
      |> Jason.encode!()
      |> Jason.decode!()

    data = %{
      server: server_data,
      past_server: past_server_data,
      past_start_date: past_start_date,
      past_end_date: past_end_date
    }

    params =
      params
      |> Map.merge(%{
        "Start date" => start_date,
        "End date" => end_date
      })

    assigns = %{
      params: params,
      presets: DatePresets.presets()
    }

    {data, assigns}
  end

  defp apply_defaults(params) do
    Map.merge(
      %{
        "date_preset" => "Last month",
        "start_date" => "",
        "end_date" => "",
        "mode" => ""
      },
      Map.get(params, "report", %{})
    )
  end
end
