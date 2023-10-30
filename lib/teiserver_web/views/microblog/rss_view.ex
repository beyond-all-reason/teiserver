defmodule TeiserverWeb.Microblog.RssView do
  use TeiserverWeb, :view

  def format_date(date) do
    date
      |> Timex.Timezone.convert("UTC")
      |> Timex.format!("{0D}-{0M}-{YYYY} {h24}:{m}:{s}")
  end

  def guid_date(date) do
    date
      |> Timex.Timezone.convert("UTC")
      |> Timex.format!("{YYYY}{0M}{0D}{h24}{m}{s}")
  end
end
