defmodule Central.Helpers.TimexHelper do
  @moduledoc """
  """

  alias Timex.{Timezone, Timezone.Local}

  # Was finding that in April it moved the time up an hour
  # every time I saved, turns out the issue was it was stored
  # as UTC but printed as +1 hour
  defp convert(timestamp, tz) do
    new_timestamp = timestamp |> Timezone.convert(tz)

    case new_timestamp do
      %Timex.AmbiguousDateTime{} -> timestamp
      _ -> new_timestamp
    end
  end

  @spec date_to_str(DateTime.t()) :: String.t()
  @spec date_to_str(DateTime.t(), list) :: String.t()
  def date_to_str(the_time), do: date_to_str(the_time, [])
  def date_to_str(nil, _), do: ""

  def date_to_str(the_time, format) when is_atom(format) do
    date_to_str(the_time, format: format)
  end

  def date_to_str(the_time, [format: :dmy_text, tz: tz]), do: dmy_text(the_time, tz)

  def date_to_str(the_time, args) do
    format = args[:format] || :dmy
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
        :day_name -> Timex.format!(the_time, "{WDfull}")
        :dmy -> Timex.format!(the_time, "{0D}/{0M}/{YYYY}")
        :ymd -> Timex.format!(the_time, "{YYYY}-{0M}-{0D}")
        :hms_dmy -> Timex.format!(the_time, "{h24}:{m}:{s} {0D}/{0M}/{YYYY}")
        :ymd_hms -> Timex.format!(the_time, "{YYYY}-{0M}-{0D} {h24}:{m}:{s}")
        :ymd_t_hms -> Timex.format!(the_time, "{YYYY}-{M}-{D}T{h24}:{m}:{s}")
        :hms -> Timex.format!(the_time, "{h24}:{m}:{s}")
        :hm_dmy -> Timex.format!(the_time, "{h24}:{m} {0D}/{0M}/{YYYY}")
        :hm -> Timex.format!(the_time, "{h24}:{m}")
        :clock24 -> Timex.format!(the_time, "{h24}{m}")
        :html_input -> Timex.format!(the_time, "{YYYY}-{0M}-{0D}T{h24}:{m}")
        :email_date -> Timex.format!(the_time, "{WDshort}, {0D} {Mshort} {YYYY} {h24}:{m}:{s} {Z}")
        :hms_or_hmsdmy -> _hms_or_hmsdmy(the_time, now)
        :hms_or_dmy -> _hms_or_dmy(the_time, now)
        :hm_or_dmy -> _hm_or_dmy(the_time, now)
        :everything -> Timex.format!(the_time, "{YYYY}-{0M}-{0D} {h24}:{m}:{s}, {WDfull}")
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

  @spec _hms_or_hmsdmy(DateTime.t(), DateTime.t()) :: String.t()
  defp _hms_or_hmsdmy(the_time, today) do
    if Timex.compare(the_time |> Timex.to_date(), today) == 0 do
      Timex.format!(the_time, "Today at {h24}:{m}:{s}")
    else
      Timex.format!(the_time, "{h24}:{m}:{s} {0D}/{0M}/{YYYY}")
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
      |> suffix

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
end
