defmodule Teiserver.Helper.TimexHelper do
  @moduledoc false

  alias Timex.{Timezone, Timezone.Local}

  # Was finding that in April it moved the time up an hour
  # every time I saved, turns out the issue was it was stored
  # as UTC but printed as +1 hour
  defp convert(timestamp, tz) do
    new_timestamp = timestamp |> Timezone.convert(tz)

    case new_timestamp do
      %Timex.AmbiguousDateTime{} -> timestamp
      {:error, _reason} -> timestamp
      _ -> new_timestamp
    end
  end

  @spec date_to_discord_str(DateTime.t()) :: String.t()
  def date_to_discord_str(the_time) do
    "<t:#{Timex.to_unix(the_time)}:f>"
  end

  @spec date_to_str(DateTime.t()) :: String.t()
  @spec date_to_str(DateTime.t(), list) :: String.t()
  def date_to_str(the_time), do: date_to_str(the_time, [])
  def date_to_str(nil, _), do: ""

  def date_to_str(the_time, format) when is_atom(format) do
    date_to_str(the_time, format: format)
  end

  def date_to_str(the_time, format: :dmy_text, tz: tz), do: dmy_text(the_time, tz)

  def date_to_str(the_time, args) do
    format = args[:format] || :ymd
    now = args[:now] || Timex.now()
    is_past = Timex.compare(now, the_time) == 1

    until_id =
      case args[:until] do
        true -> ""
        false -> ""
        nil -> ""
        s -> s
      end

    the_time = convert(the_time, args[:tz] || Local.lookup())

    time_str =
      case format do
        :day_name ->
          Timex.format!(the_time, "{WDfull}")

        :dmy ->
          Timex.format!(the_time, "{0D}/{0M}/{YYYY}")

        :ymd ->
          Timex.format!(the_time, "{YYYY}-{0M}-{0D}")

        :hms_dmy ->
          Timex.format!(the_time, "{h24}:{m}:{s} {0D}/{0M}/{YYYY}")

        :hms_ymd ->
          Timex.format!(the_time, "{h24}:{m}:{s} {YYYY}-{0M}-{0D}")

        :ymd_hms ->
          Timex.format!(the_time, "{YYYY}-{0M}-{0D} {h24}:{m}:{s}")

        :ymd_t_hms ->
          Timex.format!(the_time, "{YYYY}-{M}-{D}T{h24}:{m}:{s}")

        :hms ->
          Timex.format!(the_time, "{h24}:{m}:{s}")

        :hm_dmy ->
          Timex.format!(the_time, "{h24}:{m} {0D}/{0M}/{YYYY}")

        :hm ->
          Timex.format!(the_time, "{h24}:{m}")

        :clock24 ->
          Timex.format!(the_time, "{h24}{m}")

        :html_input ->
          Timex.format!(the_time, "{YYYY}-{0M}-{0D}T{h24}:{m}")

        :email_date ->
          Timex.format!(the_time, "{WDshort}, {0D} {Mshort} {YYYY} {h24}:{m}:{s} {Z}")

        :hms_or_hmsdmy ->
          _hms_or_hmsdmy(the_time, now)

        :hms_or_hmsymd ->
          _hms_or_hmsymd(the_time, now)

        :hms_or_dmy ->
          _hms_or_dmy(the_time, now)

        :hms_or_ymd ->
          _hms_or_ymd(the_time, now)

        :hms_or_hms_ymd ->
          _hms_or_hms_ymd(the_time, now)

        :hm_or_dmy ->
          _hm_or_dmy(the_time, now)

        :everything ->
          Timex.format!(the_time, "{YYYY}-{0M}-{0D} {h24}:{m}:{s}, {WDfull}")
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
  def time_until(the_time), do: time_until(the_time, Timex.now())
  def time_until(nil, _), do: nil

  def time_until(the_time, now) do
    the_duration = Timex.diff(now, the_time, :duration)
    is_past = Timex.compare(now, the_time) == 1
    days = Timex.Duration.to_days(the_duration)

    # We need to do this as we need days rounded off in the correct
    # direction to get the number of hours left
    hours =
      if is_past do
        Timex.Duration.to_hours(the_duration) - Float.floor(days) * 24
      else
        Timex.Duration.to_hours(the_duration) - Float.ceil(days) * 24
      end

    days = abs(days)
    hours = abs(hours)

    cond do
      2 > days and days > 1 -> "1 day, #{round(hours)} hours"
      round(days) > 1 -> "#{round(days)} days"
      round(hours) > 1 -> "#{round(hours)} hours"
      days == 0 and hours == 0 -> ""
      true -> "#{Timex.format_duration(the_duration, :humanized)}"
    end
  end

  @spec datetime_min(DateTime.t(), DateTime.t()) :: DateTime.t()
  @spec datetime_min(Date.t(), Date.t()) :: Date.t()
  def datetime_min(dt1, dt2) do
    if Timex.compare(dt1, dt2) == -1 do
      dt1
    else
      dt2
    end
  end

  @spec datetime_max(DateTime.t(), DateTime.t()) :: DateTime.t()
  @spec datetime_max(Date.t(), Date.t()) :: Date.t()
  def datetime_max(dt1, dt2) do
    if Timex.compare(dt1, dt2) == 1 do
      dt1
    else
      dt2
    end
  end

  @spec _hms_or_hmsdmy(DateTime.t(), DateTime.t()) :: String.t()
  defp _hms_or_hmsdmy(the_time, today) do
    if Timex.compare(the_time |> Timex.to_date(), today) == 0 do
      Timex.format!(the_time, "Today at {h24}:{m}:{s}")
    else
      Timex.format!(the_time, "{h24}:{m}:{s} {0D}/{0M}/{YYYY}")
    end
  end

  @spec _hms_or_hmsymd(DateTime.t(), DateTime.t()) :: String.t()
  defp _hms_or_hmsymd(the_time, today) do
    if Timex.compare(the_time |> Timex.to_date(), today) == 0 do
      Timex.format!(the_time, "Today at {h24}:{m}:{s}")
    else
      Timex.format!(the_time, "{h24}:{m}:{s} {YYYY}-{0M}-{0D}")
    end
  end

  @spec _hms_or_ymd(DateTime.t(), DateTime.t()) :: String.t()
  defp _hms_or_ymd(the_time, today) do
    if Timex.compare(the_time |> Timex.to_date(), today) == 0 do
      Timex.format!(the_time, "Today at {h24}:{m}:{s}")
    else
      Timex.format!(the_time, "{YYYY}-{0M}-{0D}")
    end
  end

  @spec _hms_or_hms_ymd(DateTime.t(), DateTime.t()) :: String.t()
  defp _hms_or_hms_ymd(the_time, today) do
    if Timex.compare(the_time |> Timex.to_date(), today) == 0 do
      Timex.format!(the_time, "Today at {h24}:{m}:{s}")
    else
      Timex.format!(the_time, "{h24}:{m}:{s} {YYYY}-{0M}-{0D}")
    end
  end

  @spec _hms_or_dmy(DateTime.t(), DateTime.t()) :: String.t()
  defp _hms_or_dmy(the_time, today) do
    if Timex.compare(the_time |> Timex.to_date(), today) == 0 do
      Timex.format!(the_time, "Today at {h24}:{m}:{s}")
    else
      Timex.format!(the_time, "{0D}/{0M}/{YYYY}")
    end
  end

  @spec _hm_or_dmy(DateTime.t(), DateTime.t()) :: String.t()
  defp _hm_or_dmy(the_time, today) do
    if Timex.compare(the_time |> Timex.to_date(), today) == 0 do
      Timex.format!(the_time, "Today at {h24}:{m}")
    else
      Timex.format!(the_time, "{0D}/{0M}/{YYYY}")
    end
  end

  # def dmy(nil), do: ""
  # def dmy(the_time) do
  #   if Map.has_key?(the_time, "day") do
  #     Timex.format!(
  #       (for {key, val} <- the_time, into: %{}, do: {String.to_atom(key), val}),
  #       "{0D}/{0M}/{YYYY}"
  #     )
  #   else
  #     Timex.format!(the_time, "{0D}/{0M}/{YYYY}")
  #   end
  # end

  defp dmy_text(nil, _), do: nil

  defp dmy_text(the_time, tz) do
    suffix =
      the_time
      |> convert(tz || Local.lookup())
      |> Timex.format!("{D}")
      |> String.to_integer()
      |> suffix()

    Timex.format!(the_time, "{D}#{suffix} {Mfull} {YYYY}")
  end

  defp suffix(1), do: "st"
  defp suffix(21), do: "st"
  defp suffix(31), do: "st"
  defp suffix(2), do: "nd"
  defp suffix(22), do: "nd"
  defp suffix(32), do: "nd"
  defp suffix(3), do: "nd"
  defp suffix(23), do: "nd"
  defp suffix(33), do: "rd"
  defp suffix(_), do: "th"

  def parse_dmy(nil), do: nil
  def parse_dmy(""), do: nil

  def parse_dmy(s) do
    Timex.parse!(s, "{0D}/{0M}/{YYYY}")
  end

  def parse_ymd(nil), do: nil
  def parse_ymd(""), do: nil

  def parse_ymd(s) do
    Timex.parse!(s, "{YYYY}-{M}-{D}")
  end

  def parse_ymd_hms(nil), do: nil
  def parse_ymd_hms(""), do: nil

  def parse_ymd_hms(s) do
    Timex.parse!(s, "{YYYY}-{M}-{D} {h24}:{m}:{s}")
  end

  def parse_ymd_t_hms(s) do
    Timex.parse!(s, "{YYYY}-{M}-{D}T{h24}:{m}:{s}")
  end

  def parse_time_input(s) do
    cond do
      String.contains?(s, ":") -> parse_ymd_hms(s)
      String.contains?(s, "-") -> parse_ymd(s)
      true -> parse_dmy(s)
    end
  end

  # def duration(start_tick, end_tick) do
  #   s = Timex.diff(end_tick, start_tick, :duration)
  #   |> Timex.Duration.to_seconds()

  #   days = :math.floor(s/86400) |> round
  #   s = s - days * 86400
  #   hours = :math.floor(s/3600) |> round
  #   s = s - hours * 3600
  #   mins = :math.floor(s/60) |> round
  #   s = s - mins * 60
  #   s = round(s)

  #   cond do
  #     days > 0 -> "#{days} days"
  #     hours > 0 -> "#{hours} hours"
  #     mins > 0 -> "#{mins}:#{s}"
  #     true -> "#{s}s"
  #   end
  # end

  def duration_to_str(nil, _), do: ""
  def duration_to_str(_, nil), do: ""

  def duration_to_str(t1, t2) do
    Timex.diff(t1, t2, :second)
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
    start =
      start_date
      |> Timex.beginning_of_day()

    last =
      end_date
      |> Timex.beginning_of_day()

    start
    |> Stream.iterate(&Timex.shift(&1, days: 1))
    |> Stream.take_while(&(Timex.compare(&1, last) == -1))
  end

  @doc """
  Wraps Timex.compare, returns true if a > b
  """
  def greater_than(nil, _), do: false
  def greater_than(_, nil), do: true

  def greater_than(a, b) do
    Timex.compare(a, b) == 1
  end

  @doc """
  Wraps Timex.compare, returns true if a < b
  """
  def less_than(nil, _), do: true
  def less_than(_, nil), do: false

  def less_than(a, b) do
    Timex.compare(a, b) == -1
  end

  def represent_minutes(nil), do: ""

  def represent_minutes(s) do
    now = Timex.now()
    until = Timex.shift(now, minutes: s)
    time_until(until, now)
  end

  def represent_seconds(nil), do: ""

  def represent_seconds(s) do
    now = Timex.now()
    until = Timex.shift(now, seconds: s)
    time_until(until, now)
  end
end
