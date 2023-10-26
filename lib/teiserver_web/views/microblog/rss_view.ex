defmodule TeiserverWeb.Microblog.RssView do
  use TeiserverWeb, :view

  def to_rfc822(date) do
    date
      |> Timex.Timezone.convert("UTC")
      |> Timex.format!("{WDshort}, {D} {Mshort} {YYYY} {h24}:{m}:{s} {Zname}")
  end
end
