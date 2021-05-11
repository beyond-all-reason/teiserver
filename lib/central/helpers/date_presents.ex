defmodule Central.Helpers.DatePresets do
  @moduledoc """

  """

  import Central.Helpers.TimexHelper

  @presets [
    "This week",
    "Last week",
    "Two weeks ago",
    "This month",
    "Last month",
    "Two months ago",
    "This year",
    "Last year",
    "Last 3 months",
    "Last 6 months",
    "Last 12 months",
    "All time"
  ]

  @long_presets [
    "This month",
    "Last month",
    "Two months ago",
    "This year",
    "Last year",
    "All time"
  ]

  @short_ranges [
    "This week",
    "Last week",
    "Two weeks ago",
    "This month",
    "Last month",
    "Two months ago"
  ]

  @long_ranges [
    "Last 3 months",
    "Last 6 months",
    "Last 12 months"
  ]

  @past_dates [
    "Today",
    "Yesterday",
    "Start of the week",
    "Start of the month",
    "Start of the quarter",
    "Start of the year",
    "Start of time"
  ]

  @future_dates [
    "Tomorrow",
    "Start of next week",
    "Start of next month",
    "Start of next quarter",
    "Start of next year",
    "End of time"
  ]

  # We use ++ here since the order matters
  @spec presets() :: list(String.t())
  def presets(), do: @presets ++ ["All time"]

  @spec long_presets() :: list(String.t())
  def long_presets(), do: @long_presets ++ ["All time"]

  @spec short_ranges() :: list(String.t())
  def short_ranges(), do: @short_ranges ++ ["All time"]

  @spec long_ranges() :: list(String.t())
  def long_ranges(), do: @long_ranges ++ ["All time"]

  @spec past_dates() :: list(String.t())
  def past_dates(), do: @past_dates

  @spec future_dates() :: list(String.t())
  def future_dates(), do: @future_dates

  @spec parse(String.t()) :: Date.t()
  def parse("Today"), do: Timex.today()
  def parse("Yesterday"), do: Timex.today() |> Timex.shift(days: -1)
  def parse("Start of the week"), do: Timex.today() |> Timex.beginning_of_week()
  def parse("Start of the month"), do: Timex.today() |> Timex.beginning_of_month()
  def parse("Start of the quarter"), do: Timex.today() |> Timex.beginning_of_quarter()
  def parse("Start of the year"), do: Timex.today() |> Timex.beginning_of_year()
  def parse("Start of time"), do: Timex.to_date({1, 1, 1})

  def parse("Tomorrow"), do: Timex.today() |> Timex.shift(days: 1)

  def parse("Start of next week"),
    do: Timex.today() |> Timex.beginning_of_week() |> Timex.shift(weeks: 1)

  def parse("Start of next month"),
    do: Timex.today() |> Timex.beginning_of_month() |> Timex.shift(months: 1)

  def parse("Start of next quarter"),
    do: Timex.today() |> Timex.beginning_of_quarter() |> Timex.shift(months: 3)

  def parse("Start of next year"),
    do: Timex.today() |> Timex.beginning_of_year() |> Timex.shift(years: 1)

  def parse("End of time"), do: Timex.to_date({9999, 1, 1})

  def parse(period), do: parse(period, nil, nil)

  @spec parse(String.t(), String.t(), String.t()) :: {Date.t(), Date.t()}
  def parse(period_name, start_date, end_date) do
    if start_date == "" or end_date == "" do
      _parse_named_period(period_name)
    else
      today = Timex.today()

      {
        if(start_date != "",
          do: parse_time_input(start_date),
          else: Timex.to_date({today.year, 1, 1})
        ),
        if(end_date != "", do: parse_time_input(end_date), else: Timex.shift(today, days: 1))
      }
    end
  end

  def _parse_named_period("This week") do
    today = Timex.today()
    start = Timex.beginning_of_week(today)

    {start, Timex.shift(today, weeks: 1)}
  end

  def _parse_named_period("Last week") do
    today = Timex.today()

    start =
      Timex.beginning_of_week(today)
      |> Timex.shift(weeks: -1)

    {start, Timex.shift(start, weeks: 1)}
  end

  def _parse_named_period("Two weeks ago") do
    today = Timex.today()

    start =
      Timex.beginning_of_week(today)
      |> Timex.shift(weeks: -2)

    {start, Timex.shift(start, weeks: 1)}
  end

  def _parse_named_period("This month") do
    today = Timex.today()
    start = Timex.to_date({today.year, today.month, 1})

    {start, Timex.shift(start, months: 1)}
  end

  def _parse_named_period("Last month") do
    today = Timex.today()

    start =
      Timex.to_date({today.year, today.month, 1})
      |> Timex.shift(months: -1)

    {start, Timex.shift(start, months: 1)}
  end

  def _parse_named_period("Two months ago") do
    today = Timex.today()

    start =
      Timex.to_date({today.year, today.month, 1})
      |> Timex.shift(months: -2)

    {start, Timex.shift(start, months: 1)}
  end

  def _parse_named_period("This year") do
    today = Timex.today()
    start = Timex.to_date({today.year, 1, 1})

    {start, Timex.shift(start, years: 1)}
  end

  def _parse_named_period("Last year") do
    today = Timex.today()

    start =
      Timex.to_date({today.year, 1, 1})
      |> Timex.shift(years: -1)

    {start, Timex.shift(start, years: 1)}
  end

  def _parse_named_period("All time") do
    start = Timex.to_date({1, 1, 1})

    {start, Timex.shift(Timex.today(), years: 1000)}
  end

  def _parse_named_period("Last 3 months") do
    today = Timex.today()

    start =
      Timex.to_date({today.year, today.month, 1})
      |> Timex.shift(months: -3)

    {start, Timex.shift(today, days: 1)}
  end

  def _parse_named_period("Last 6 months") do
    today = Timex.today()

    start =
      Timex.to_date({today.year, today.month, 1})
      |> Timex.shift(months: -6)

    {start, Timex.shift(today, days: 1)}
  end

  def _parse_named_period("Last 12 months") do
    today = Timex.today()

    start =
      Timex.to_date({today.year, today.month, 1})
      |> Timex.shift(months: -12)

    {start, Timex.shift(today, days: 1)}
  end

  def as_datetimes({start_date, end_date}) do
    {Timex.to_datetime(start_date), Timex.to_datetime(end_date)}
  end

  # def guess_preset(date, preset_list) do
  #   result = preset_list
  #   |> Enum.filter(fn p ->
  #     date == parse(p)
  #   end)
  #   hd(result ++ [nil])
  # end

  # def parse(chosen_preset, _, _), do: raise "No handler for preset of '#{chosen_preset}'"
end
