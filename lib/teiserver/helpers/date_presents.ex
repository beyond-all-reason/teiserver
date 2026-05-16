defmodule Teiserver.Helper.DatePresets do
  @moduledoc false

  import Teiserver.Helper.DateHelper

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
    "This month",
    "Last month",
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
  def presets, do: @presets

  @spec long_presets() :: list(String.t())
  def long_presets, do: @long_presets

  @spec short_ranges() :: list(String.t())
  def short_ranges, do: @short_ranges ++ ["All time"]

  @spec long_ranges() :: list(String.t())
  def long_ranges, do: @long_ranges ++ ["All time"]

  @spec past_dates() :: list(String.t())
  def past_dates, do: @past_dates

  @spec future_dates() :: list(String.t())
  def future_dates, do: @future_dates

  @spec parse(String.t()) :: Date.t()
  def parse("Today"), do: Date.utc_today()
  def parse("Yesterday"), do: Date.add(Date.utc_today(), -1)
  def parse("Start of the week"), do: Date.utc_today() |> Date.beginning_of_week()
  def parse("Start of the month"), do: Date.utc_today() |> beginning_of_month()
  def parse("Start of the quarter"), do: Date.utc_today() |> beginning_of_quarter()
  def parse("Start of the year"), do: Date.utc_today() |> beginning_of_year()
  def parse("Start of time"), do: Date.new!(1, 1, 1)

  def parse("Tomorrow"), do: Date.add(Date.utc_today(), 1)

  def parse("Start of next week"),
    do: Date.utc_today() |> Date.beginning_of_week() |> Date.add(7)

  def parse("Start of next month"),
    do: Date.utc_today() |> beginning_of_month() |> shift_months(1)

  def parse("Start of next quarter"),
    do: Date.utc_today() |> beginning_of_quarter() |> shift_months(3)

  def parse("Start of next year"),
    do: Date.utc_today() |> beginning_of_year() |> shift_years(1)

  def parse("End of time"), do: Date.new!(9999, 1, 1)

  def parse(period), do: parse(period, "", "")

  @spec parse(String.t(), String.t(), String.t()) :: {Date.t(), Date.t()}
  def parse(period_name, start_date, end_date) do
    cond do
      start_date == "" and end_date == "" ->
        _parse_named_period(period_name)

      start_date == "" ->
        {Date.new!(Date.utc_today().year, 1, 1), parse_time_input(end_date)}

      end_date == "" ->
        {parse_time_input(start_date), Date.add(Date.utc_today(), 1)}

      true ->
        {
          parse_time_input(start_date),
          parse_time_input(end_date)
        }
    end
  end

  @spec _parse_named_period(String.t()) :: {Date.t() | DateTime.t(), Date.t() | DateTime.t()}
  def _parse_named_period("This week") do
    today = Date.utc_today()
    start = Date.beginning_of_week(today)

    {start, Date.add(today, 7)}
  end

  def _parse_named_period("Last week") do
    today = Date.utc_today()

    start =
      Date.beginning_of_week(today)
      |> Date.add(-7)

    {start, Date.add(start, 7)}
  end

  def _parse_named_period("Two weeks ago") do
    today = Date.utc_today()

    start =
      Date.beginning_of_week(today)
      |> Date.add(-14)

    {start, Date.add(start, 7)}
  end

  def _parse_named_period("This month") do
    today = Date.utc_today()
    start = Date.new!(today.year, today.month, 1)

    {start, Date.add(today, 1)}
  end

  def _parse_named_period("Last month") do
    today = Date.utc_today()

    start =
      Date.new!(today.year, today.month, 1)
      |> shift_months(-1)

    {start, shift_months(start, 1)}
  end

  def _parse_named_period("This quarter") do
    today = Date.utc_today()
    {beginning_of_quarter(today), end_of_quarter(today)}
  end

  def _parse_named_period("Last quarter") do
    today = Date.utc_today()

    start =
      today
      |> shift_months(-3)
      |> beginning_of_quarter()

    {start, beginning_of_quarter(today)}
  end

  def _parse_named_period("Two months ago") do
    today = Date.utc_today()

    start =
      Date.new!(today.year, today.month, 1)
      |> shift_months(-2)

    {start, shift_months(start, 1)}
  end

  def _parse_named_period("This year") do
    today = Date.utc_today()
    start = Date.new!(today.year, 1, 1)

    {start, shift_years(start, 1)}
  end

  def _parse_named_period("Last year") do
    today = Date.utc_today()

    start =
      Date.new!(today.year, 1, 1)
      |> shift_years(-1)

    {start, shift_years(start, 1)}
  end

  def _parse_named_period("All time") do
    start = Date.new!(1900, 1, 1)

    {start, shift_years(Date.utc_today(), 1000)}
  end

  def _parse_named_period("Last 3 months") do
    today = Date.utc_today()

    start =
      Date.new!(today.year, today.month, 1)
      |> shift_months(-3)

    {start, Date.add(today, 1)}
  end

  def _parse_named_period("Last 6 months") do
    today = Date.utc_today()

    start =
      Date.new!(today.year, today.month, 1)
      |> shift_months(-6)

    {start, Date.add(today, 1)}
  end

  def _parse_named_period("Last 12 months") do
    today = Date.utc_today()

    start =
      Date.new!(today.year, today.month, 1)
      |> shift_months(-12)

    {start, Date.add(today, 1)}
  end

  @spec as_datetimes({Date.t(), Date.t()}) :: {DateTime.t(), DateTime.t()}
  def as_datetimes({start_date, end_date}) do
    {to_datetime(start_date), to_datetime(end_date)}
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
