defmodule TeiserverWeb.Microblog.RssView do
  alias Timex.Timezone

  use TeiserverWeb, :view

  def format_date(date) do
    date
    |> Timezone.convert("UTC")
    # |> Timex.format!("{0D}-{0M}-{YYYY} {h24}:{m}:{s}")
    |> Calendar.strftime("%Y-%m-%d %I:%M:%S")
  end

  def guid_date(date) do
    date
    |> Timezone.convert("UTC")
    # |> Timex.format!("{YYYY}{0M}{0D}{h24}{m}{s}")
    |> Calendar.strftime("%Y%m%d%H%M%S")
  end
end
