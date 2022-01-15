defmodule Central.General.DateSeries do
  @moduledoc """
  Designed to take postgres date truncs and make a series from them

  Structure is {{year, month, day}, {hour, minute, second, millisecond}}
  """

  def series("weekly") do
    ~w(Mon Tue Wed Thu Fri Sat Sun)
  end

  def series("monthly") do
    1..31
    |> Enum.map(&to_string/1)
  end

  def series("yearly") do
    ~w(Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec)
  end

  def series(mode, dates) when is_list(dates) do
    first = hd(dates)
    last = hd(Enum.reverse(dates))

    series(mode, first, last)
  end

  def series(mode, first_date) do
    series(mode, first_date, Timex.today())
  end

  def series("daily", first_date, last_date), do: series("day", first_date, last_date)

  def series("day", first_date, last_date) do
    start =
      first_date
      |> parse
      |> Timex.beginning_of_day()

    last =
      last_date
      |> parse
      |> Timex.beginning_of_day()

    start
    |> Stream.iterate(&Timex.shift(&1, days: 1))
    |> Stream.take_while(&(Timex.compare(&1, last) == -1))
  end

  def series("weekly", first_date, last_date), do: series("week", first_date, last_date)

  def series("week", first_date, last_date) do
    start =
      first_date
      |> parse
      |> Timex.beginning_of_week()

    last =
      last_date
      |> parse
      |> Timex.beginning_of_week()

    start
    |> Stream.iterate(&Timex.shift(&1, weeks: 1))
    |> Stream.take_while(&(Timex.compare(&1, last) == -1))
  end

  def series("month", first_date, last_date) do
    start =
      first_date
      |> parse
      |> Timex.beginning_of_month()

    last =
      last_date
      |> parse
      |> Timex.beginning_of_month()

    start
    |> Stream.iterate(&Timex.shift(&1, months: 1))
    |> Stream.take_while(&(Timex.compare(&1, last) == -1))
  end

  def series("quarterly", first_date, last_date), do: series("quarter", first_date, last_date)

  def series("quarter", first_date, last_date) do
    start =
      first_date
      |> parse
      |> Timex.beginning_of_quarter()

    last =
      last_date
      |> parse
      |> Timex.beginning_of_quarter()

    start
    |> Stream.iterate(&Timex.shift(&1, months: 3))
    |> Stream.take_while(&(Timex.compare(&1, last) == -1))
  end

  def series("yearly", first_date, last_date), do: series("year", first_date, last_date)

  def series("year", first_date, last_date) do
    start =
      first_date
      |> parse
      |> Timex.beginning_of_year()

    last =
      last_date
      |> parse
      |> Timex.beginning_of_year()

    start
    |> Stream.iterate(&Timex.shift(&1, years: 1))
    |> Stream.take_while(&(Timex.compare(&1, last) == -1))
  end

  def parse(d) do
    case d do
      {_, _, _} -> to_timex(d)
      {{_, _, _}, {_, _, _, _}} -> to_timex(d)
      _ -> d
    end
  end

  defp to_timex({y, m, d}) do
    "#{pad(d)}/#{pad(m)}/#{y}"
    |> Timex.parse!("{D}/{M}/{YYYY}")
  end

  defp to_timex({{y, m, d}, {hh, mm, ss, _ms}}) do
    "#{pad(d)}/#{pad(m)}/#{y} #{pad(hh)}:#{pad(mm)}:#{pad(ss)}"
    |> Timex.parse!("{D}/{M}/{YYYY} {h24}:{m}:{s}")
  end

  # defp to_timex({{y, m, d}, {_hh, _mm, _ss, _ms}}) do
  #   to_timex({y, m, d})
  # end

  # defp to_timex({y, m, d}) do
  #   "#{pad d}/#{pad m}/#{y}"
  #   |> Timex.parse!("{D}/{M}/{YYYY}")
  # end

  @spec pad(integer) :: String.t()
  defp pad(number) do
    String.pad_leading("#{number}", 2, "0")
  end
end
