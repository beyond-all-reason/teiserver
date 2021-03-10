defmodule CentralWeb.Logging.ReportLib do
  use CentralWeb, :library

  # alias Central.Account.User
  alias Central.Logging.PageViewLog
  alias Central.Logging.PageViewLogLib

  import Central.Helpers.TimexHelper, only: [parse_dmy: 1]

  defp parse_params(params) do
    %{
      start_date: parse_dmy(params["start_date"]) || Timex.shift(Timex.today(), days: -31),
      end_date: parse_dmy(params["start_date"]) || Timex.shift(Timex.today(), days: 1),
      account_user: params["account_user"] || nil,
      no_root: params["no_root"] || nil,
      split: params["split"] || ""
    }
  end

  def line_chart(params) do
    params = parse_params(params)

    # Get the log aggregates as {date, section, count}
    logs =
      PageViewLogLib.get_page_view_logs()
      |> PageViewLogLib.search(start_date: params[:start_date])
      |> PageViewLogLib.search(end_date: params[:end_date])
      |> PageViewLogLib.search(account_user: params[:account_user])
      |> PageViewLogLib.search(no_root: params[:no_root])
      |> aggregate_logs(:count, :daily, params[:split])
      |> Repo.all()

    # Get the min and max dates
    min_date =
      logs
      |> Enum.take(1)
      |> hd
      |> elem(0)

    max_date =
      logs
      |> Enum.take(-1)
      |> hd
      |> elem(0)
      |> Timex.shift(days: 1)

    # Arrange all the logs as %{section: %{date: count}}
    logs
    |> Enum.group_by(
      fn {_, section, _} ->
        section
      end,
      fn {date, _, count} ->
        {date, count}
      end
    )
    |> Enum.map(fn {section, values} ->
      {
        # This is to remove any empty line
        section || "Other",
        values
        |> Enum.map(fn {date, count} ->
          {date, count}
        end)
        |> Map.new()
      }
    end)
    |> Enum.map(fn {key, values} ->
      make_nvd3_line_chart(
        key,
        fill_in_missing_dates(min_date, max_date, values)
      )
    end)
  end

  defp build_date_series(min_date, max_date), do: build_date_series(min_date, max_date, :days)

  defp build_date_series(min_date, max_date, :days) do
    # Takes a min and max date and creates a list of dates between them
    # based on the granularity provided.

    1..Timex.diff(max_date, min_date, :days)
    |> Enum.map(fn d ->
      Timex.shift(min_date, days: d - 1)
    end)
  end

  defp fill_in_missing_dates(min_date, max_date, series) do
    dates = build_date_series(min_date, max_date)

    dates
    |> Enum.map(fn d ->
      {d, Map.get(series, d, 0)}
    end)
    |> Map.new()
  end

  defp make_nvd3_line_chart(key, values) do
    # Takes data in the format
    # key, [[{timex-date}, value], [{timex-date}, value], ...]

    # Exports data in the format
    # %{
    #   key: "line name",
    #   values: [["dmy_date", #number], ["dmy_date", #number], ...]
    # },

    %{
      key: key,
      values:
        values
        |> Enum.map(fn {{y, m, d}, value} ->
          ["#{y}/#{m}/#{d}", value]
        end)
    }
  end

  def table(_params) do
  end

  defp aggregate_logs(query, :count, :daily, "") do
    from logs in query,
      group_by: fragment("date(?)", logs.inserted_at),
      order_by: [asc: fragment("date(?)", logs.inserted_at)],
      select: {
        fragment("date(?)", logs.inserted_at),
        "all",
        count(logs.id)
      }
  end

  defp aggregate_logs(query, :count, :daily, "section") do
    from logs in query,
      group_by: logs.section,
      group_by: fragment("date(?)", logs.inserted_at),
      order_by: [asc: fragment("date(?)", logs.inserted_at)],
      select: {
        fragment("date(?)", logs.inserted_at),
        logs.section,
        count(logs.id)
      }
  end

  # OLD STUFF
  def daily_count_by_section(start_date, end_date) do
    from l in PageViewLog,
      where: l.inserted_at >= ^start_date,
      where: l.inserted_at <= ^end_date,
      where: l.section not in ["load_test"],
      group_by: l.section,
      # date(l.inserted_at),
      group_by: fragment("date(?)", l.inserted_at),
      select: {fragment("date(?)", l.inserted_at), l.section, count(l.id)},
      order_by: [asc: l.section],
      order_by: [asc: fragment("date(?)", l.inserted_at)]
  end
end
