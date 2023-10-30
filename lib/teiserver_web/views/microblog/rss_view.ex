defmodule TeiserverWeb.Microblog.RssView do
  use TeiserverWeb, :view

  def format_date(date) do
    # date
    #   |> Timex.Timezone.convert("UTC")
    #   |> Timex.format!("{WDshort}, {D} {Mshort} {YYYY} {h24}:{m}:{s} {Zname}")

    date
      |> Timex.Timezone.convert("UTC")
      |> Timex.format!("{0D}-{0M}-{YYYY} {h24}:{m}:{s}")
  end
end
