defmodule Central.Helpers.ReportHelper do
  # The intent here was for a function to fill in empty weeks with 0's
  # for now though we're allowing empty weeks 

  # # Given a start and an end, it will fill in all weekly segments with zeroes
  # def fill_in_segments(data, "weekly", default \\ 0) do
  #   {first, _} = hd(data)
  #   {last, _} = hd(Enum.reverse(data))

  #   get_weekly_keys(fy, fw, ly, lw)
  #   |> Enum.map(fn {y, w} ->
  #     ["#{y}:#{w}", Map.get(data, {y, w}, default)]
  #   end)
  # end

  # defp get_weekly_keys(first, last) do
  #   IO.puts ""
  #   IO.inspect first
  #   IO.inspect last
  #   IO.puts ""

  #   cond do
  #     first_year == last_year ->
  #       # Same? We just need the weeks then!
  #       Range.new(first_week, last_week)
  #       |> Enum.map(fn w -> {first_year, w} end)
  #     # first_year == (last_year - 1) ->
  #     #   # Consecutive years
  #     #   get_weekly_keys(first_year, first_week, first_year, 52)
  #     #   ++ get_weekly_keys(last_year, 1, last_year, last_week)
  #     # true ->
  #     #   # Not consecutive years
  #     #   get_weekly_keys(first_year, first_week, first_year, 52)
  #     #   ++ get_weekly_keys(first_year + 1, 0, (last_year - 1), 52)
  #     #   ++ get_weekly_keys(last_year, 1, last_year, last_week)
  #   end
  # end

  # Useful for charts and other areas where you would aggregate by date
  # Singular means you want that as a unit
  def render_segment("day", d), do: Timex.format!(d, "{WDshort} {D}/{M}")
  def render_segment("week", d), do: Timex.format!(d, "{D}/{M}")
  def render_segment("month", d), do: Timex.format!(d, "{Mshort} {YYYY}")
  def render_segment("quarter", d), do: Timex.format!(d, "{Mfull} {YYYY}")
  def render_segment("year", d), do: Timex.format!(d, "{YYYY}")
  def render_segment("all time", _), do: ""

  def render_segment("weekly", d), do: Timex.format!(d, "{0D}/{0M}")
  def render_segment("monthly", d), do: Timex.format!(d, "{Mshort} {YYYY}")
  def render_segment("yearly", d), do: Timex.format!(d, "{YYYY}")

  # Catchall
  def render_segment(_, v), do: v

  # Converts the date for a segment part into the column identifier used
  def convert_to_segment_part("weekly", d), do: Timex.format!(d, "{WDshort}")
  def convert_to_segment_part("monthly", d), do: Timex.format!(d, "{D}")
  def convert_to_segment_part("yearly", d), do: Timex.format!(d, "{Mshort}")
end
