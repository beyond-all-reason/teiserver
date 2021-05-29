defmodule Teiserver.Tasks.PersistTelemetryDayTask do
  use Oban.Worker, queue: :teiserver
  alias Teiserver.Telemetry

  @impl Oban.Worker
  @spec perform(any) :: :ok
  def perform(_) do
    _last_date = Telemetry.get_last_telemtry_day_log()

    # date =
    #   if last_date == nil do
    #     Logging.get_first_page_view_log_date()
    #     |> Timex.to_date()
    #   else
    #     last_date
    #     |> Timex.shift(days: 1)
    #   end

    # if Timex.compare(date, Timex.today()) == -1 do
    #   run(date, cleanup: true)

    #   new_date = Timex.shift(date, days: 1)

    #   if Timex.compare(new_date, Timex.today()) == -1 do
    #     %{}
    #     |> Central.Logging.AggregateViewLogsTask.new()
    #     |> Oban.insert()
    #   end
    # end

    :ok
  end
end
