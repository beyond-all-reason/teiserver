defmodule Teiserver.Helper.DateHelper do
  @moduledoc false

  defp convert(%Date{} = date, tz) do
    convert(to_datetime(date), tz)
  end

  defp convert(%DateTime{} = timestamp, tz) do
    case DateTime.shift_zone(timestamp, tz, Tzdata.TimeZoneDatabase) do
      {:ok, new_timestamp} -> new_timestamp
      _error -> timestamp
    end
  end

  @doc """
  Wraps the Calendar.strftime function to give a different
  output if it is the same day (time) or a different day (date)
  """
  @spec hms_or_ymd(DateTime.t()) :: String.t()
  def hms_or_ymd(%DateTime{} = the_time) do
    time_date = DateTime.to_date(the_time)
    today_date = DateTime.new!(today(), ~T[00:00:00.0])

    if Date.compare(time_date, today_date) == :eq do
      Calendar.strftime(the_time, "%X")
    else
      Calendar.strftime(the_time, "%x")
    end
  end

  def strftime(the_time, :ymd_hms) do
    Calendar.strftime(the_time, "%Y-%m-%d %I:%M:%S")
  end

  @doc """
  Return a date object for today
  """
  @spec today() :: Date.t()
  def today do
    DateTime.utc_now()
    |> DateTime.to_date()
  end

  @spec compare(
          DateTime.t() | NaiveDateTime.t() | Date.t(),
          DateTime.t() | NaiveDateTime.t() | Date.t()
        ) :: :lt | :gt | :eq
  def compare(%Date{} = d1, %Date{} = d2), do: Date.compare(d1, d2)
  def compare(%DateTime{} = d1, %DateTime{} = d2), do: DateTime.compare(d1, d2)
  def compare(%NaiveDateTime{} = d1, %NaiveDateTime{} = d2), do: NaiveDateTime.compare(d1, d2)
  def compare(d1, d2), do: to_utc_datetime(d1) |> DateTime.compare(to_utc_datetime(d2))

  @spec date_to_discord_str(DateTime.t() | NaiveDateTime.t()) :: String.t()
  def date_to_discord_str(the_time) do
    "<t:#{the_time |> to_utc_datetime() |> DateTime.to_unix()}:f>"
  end

  @spec date_to_str(Date.t() | DateTime.t()) :: String.t()
  @spec date_to_str(Date.t() | DateTime.t(), list) :: String.t()
  def date_to_str(the_time), do: date_to_str(the_time, [])
  def date_to_str(nil, _format), do: ""

  def date_to_str(the_time, format) when is_atom(format) do
    date_to_str(the_time, format: format)
  end

  def date_to_str(%NaiveDateTime{} = the_time, args) do
    the_time
    |> DateTime.from_naive!("Etc/UTC")
    |> date_to_str(args)
  end

  def date_to_str(the_time, args) do
    format = args[:format] || :ymd
    now = args[:now] || DateTime.utc_now()
    is_past = compare(now, the_time) == :gt

    until_id =
      case args[:until] do
        true -> ""
        false -> ""
        nil -> ""
        s -> s
      end

    the_time = convert(the_time, args[:tz] || "UTC")

    time_str =
      case format do
        :dmy ->
          Calendar.strftime(the_time, "%d/%m/%Y")

        :ymd ->
          Calendar.strftime(the_time, "%Y-%m-%d")

        :hms_dmy ->
          Calendar.strftime(the_time, "%I:%M:%S %d/%m/%Y")

        :ymd_hms ->
          Calendar.strftime(the_time, "%Y-%m-%d %I:%M:%S")

        :hms ->
          Calendar.strftime(the_time, "%I:%M:%S")

        :email_date ->
          Calendar.strftime(the_time, "%a, %d %b %Y %H:%M:%S %z")

        :hms_or_dmy ->
          _hms_or_dmy(the_time, now)

        :hms_or_ymd ->
          hms_or_ymd(the_time)

        :hms_or_hms_ymd ->
          _hms_or_hms_ymd(the_time, now)
      end

    until_str =
      if args[:until] do
        case time_until(the_time, now) do
          "" ->
            ""

          until_str ->
            if is_past do
              ", " <> until_str <> " ago"
            else
              ", in " <> until_str
            end
        end
      end

    if until_id != "" do
      "#{time_str}<span id='#{until_id}'>#{until_str}</span>"
    else
      "#{time_str}#{until_str}"
    end
  end

  @spec time_until(DateTime.t()) :: String.t()
  @spec time_until(DateTime.t(), DateTime.t()) :: String.t()
  def time_until(the_time), do: time_until(the_time, DateTime.utc_now())
  def time_until(nil, _now), do: nil

  def time_until(the_time, now) do
    diff_seconds = DateTime.diff(now, the_time)
    abs_seconds = abs(diff_seconds)
    days = abs_seconds / 86400.0
    hours = rem(abs_seconds, 86400) / 3600.0

    cond do
      2 > days and days > 1 -> "1 day, #{round(hours)} hours"
      round(days) > 1 -> "#{round(days)} days"
      round(hours) > 1 -> "#{round(hours)} hours"
      abs_seconds == 0 -> ""
      true -> duration_to_str(abs_seconds)
    end
  end

  @spec _hms_or_hms_ymd(DateTime.t(), DateTime.t()) :: String.t()
  defp _hms_or_hms_ymd(the_time, today) do
    if DateTime.to_date(the_time) == DateTime.to_date(today) do
      Calendar.strftime(the_time, "Today at %H:%M:%S")
    else
      Calendar.strftime(the_time, "%H:%M:%S %Y-%m-%d")
    end
  end

  @spec _hms_or_dmy(DateTime.t(), DateTime.t()) :: String.t()
  defp _hms_or_dmy(the_time, today) do
    if DateTime.to_date(the_time) == DateTime.to_date(today) do
      Calendar.strftime(the_time, "Today at %I:%M:%S")
    else
      Calendar.strftime(the_time, "%d/%m/%Y")
    end
  end

  @doc """
  Parses a date string in "DD/MM/YYYY" format into a `Date`.
  """
  def parse_dmy(nil), do: nil
  def parse_dmy(""), do: nil

  def parse_dmy(s) do
    [day, month, year] = String.split(s, "/")

    year
    |> String.to_integer()
    |> Date.new!(String.to_integer(month), String.to_integer(day))
  end

  @doc """
  Parses a date string in "YYYY-MM-DD" format into a `Date`.
  """
  def parse_ymd(nil), do: nil
  def parse_ymd(""), do: nil

  def parse_ymd(s) do
    [year, month, day] = String.split(s, "-")

    year
    |> String.to_integer()
    |> Date.new!(String.to_integer(month), String.to_integer(day))
  end

  @doc """
  Parses a datetime string in "YYYY-MM-DD HH:MM:SS" format into a `NaiveDateTime`.
  """
  def parse_ymd_hms(nil), do: nil
  def parse_ymd_hms(""), do: nil

  def parse_ymd_hms(s) do
    [date_str, time_str] = String.split(s, " ", parts: 2)
    [year, month, day] = String.split(date_str, "-")
    [hour, minute, second] = String.split(time_str, ":")

    year
    |> String.to_integer()
    |> NaiveDateTime.new!(
      String.to_integer(month),
      String.to_integer(day),
      String.to_integer(hour),
      String.to_integer(minute),
      String.to_integer(second)
    )
  end

  @doc """
  Parses a date/datetime string by detecting its format from separators:
  contains ":" -> "YYYY-MM-DD HH:MM:SS", contains "-" -> "YYYY-MM-DD", otherwise -> "DD/MM/YYYY".
  """
  def parse_time_input(s) do
    cond do
      String.contains?(s, ":") -> parse_ymd_hms(s)
      String.contains?(s, "-") -> parse_ymd(s)
      true -> parse_dmy(s)
    end
  end

  def duration_to_str(nil, _t2), do: ""
  def duration_to_str(_t1, nil), do: ""

  def duration_to_str(t1, t2) do
    NaiveDateTime.diff(t1, t2, :second)
    |> abs()
    |> duration_to_str()
  end

  @minute 60
  @hour 60 * 60
  @day 60 * 60 * 24
  def duration_to_str(seconds) do
    cond do
      seconds >= @day ->
        days = (seconds / @day) |> :math.floor() |> round()

        if days == 1 do
          "#{days} day"
        else
          "#{days} days"
        end

      seconds >= @hour ->
        hours = (seconds / @hour) |> :math.floor() |> round()

        if hours == 1 do
          "#{hours} hour"
        else
          "#{hours} hours"
        end

      true ->
        "#{seconds} seconds"
    end
  end

  def duration_to_str_short(nil), do: nil

  def duration_to_str_short(seconds) do
    {days, remaining} =
      if seconds >= @day do
        days = (seconds / @day) |> :math.floor() |> round()
        {days, seconds - days * @day}
      else
        {0, seconds}
      end

    {hours, remaining} =
      if remaining >= @hour do
        hours = (remaining / @hour) |> :math.floor() |> round()
        {hours, remaining - hours * @hour}
      else
        {0, remaining}
      end

    {minutes, remaining} =
      if remaining >= @minute do
        minutes = (remaining / @minute) |> :math.floor() |> round()
        {minutes, remaining - minutes * @minute}
      else
        {0, remaining}
      end

    minutes = if minutes < 10, do: "0#{minutes}", else: minutes
    remaining = if remaining < 10, do: "0#{remaining}", else: remaining

    [
      if(days > 0, do: "#{days}d "),
      if(hours > 0, do: "#{hours}:"),
      "#{minutes}:",
      "#{remaining}"
    ]
    |> Enum.reject(fn v -> v == nil end)
    |> Enum.join("")
  end

  def make_date_series(:days, start_date, end_date) do
    start = %{start_date | hour: 0, minute: 0, second: 0, microsecond: {0, 0}}
    last = %{end_date | hour: 0, minute: 0, second: 0, microsecond: {0, 0}}

    start
    |> Stream.iterate(&DateTime.shift(&1, day: 1))
    |> Stream.take_while(&(compare(&1, last) == :lt))
  end

  @doc """
  Returns true if a > b
  """
  def greater_than(nil, _b), do: false
  def greater_than(_a, nil), do: true

  def greater_than(d1, d2), do: compare(d1, d2) == :gt

  @doc """
  Returns true if a < b
  """
  def less_than(nil, _b), do: true
  def less_than(_a, nil), do: false

  def less_than(d1, d2), do: compare(d1, d2) == :lt

  def represent_minutes(nil), do: ""

  def represent_minutes(s) do
    now = DateTime.utc_now()
    until = DateTime.shift(now, minute: s)
    time_until(until, now)
  end

  def represent_seconds(nil), do: ""

  def represent_seconds(s) do
    now = DateTime.utc_now()
    until = DateTime.shift(now, second: s)
    time_until(until, now)
  end

  # --- Date/DateTime helpers replacing Timex functions ---

  @spec to_datetime(Date.t()) :: DateTime.t()
  def to_datetime(%Date{} = date), do: DateTime.new!(date, ~T[00:00:00], "Etc/UTC")

  defp to_utc_datetime(%DateTime{} = dt), do: dt
  defp to_utc_datetime(%NaiveDateTime{} = ndt), do: DateTime.from_naive!(ndt, "Etc/UTC")
  defp to_utc_datetime(%Date{} = d), do: DateTime.new!(d, ~T[00:00:00], "Etc/UTC")

  @spec beginning_of_day(DateTime.t()) :: DateTime.t()
  def beginning_of_day(dt), do: %{dt | hour: 0, minute: 0, second: 0, microsecond: {0, 0}}

  @spec beginning_of_month(Date.t() | DateTime.t()) :: Date.t() | DateTime.t()
  def beginning_of_month(date), do: %{date | day: 1}

  @spec beginning_of_quarter(Date.t() | DateTime.t()) :: Date.t() | DateTime.t()
  def beginning_of_quarter(date) do
    month = (quarter(date) - 1) * 3 + 1
    %{date | month: month, day: 1}
  end

  @spec beginning_of_year(Date.t() | DateTime.t()) :: Date.t() | DateTime.t()
  def beginning_of_year(date), do: %{date | month: 1, day: 1}

  @spec end_of_quarter(Date.t() | DateTime.t()) :: Date.t() | DateTime.t()
  def end_of_quarter(date) do
    month = quarter(date) * 3
    day = Date.days_in_month(%{date | month: month})
    %{date | month: month, day: day}
  end

  @spec end_of_year(Date.t() | DateTime.t()) :: Date.t() | DateTime.t()
  def end_of_year(date), do: %{date | month: 12, day: 31}

  @spec iso_week(Date.t() | DateTime.t()) :: {integer(), integer()}
  def iso_week(date) do
    :calendar.iso_week_number({date.year, date.month, date.day})
  end

  @spec quarter(Date.t() | DateTime.t()) :: integer()
  def quarter(date), do: div(date.month - 1, 3) + 1

  @doc """
  Converts human inputs like "3d" into a date relative to now.
  """
  @human_input_regex ~r/([1-9][0-9]*?)\s?(s|seconds?|h|hours?|d|days?|m|months?|y|years?)/

  @spec human_input_to_datetime(String.t(), DateTime.t() | nil) :: {:ok, DateTime.t()} | nil
  def human_input_to_datetime(human_input, now \\ nil) do
    now = now || DateTime.utc_now()
    human_input = String.downcase(human_input)

    case Regex.run(@human_input_regex, human_input) do
      [_full, count, unit] ->
        count = String.to_integer(count)
        unit = String.first(unit)

        duration =
          case unit do
            "s" -> Duration.new!(second: count)
            "h" -> Duration.new!(hour: count)
            "d" -> Duration.new!(day: count)
            "m" -> Duration.new!(month: count)
            "y" -> Duration.new!(year: count)
          end

        {:ok, DateTime.shift(now, duration)}

      _any_other ->
        nil
    end
  end
end
