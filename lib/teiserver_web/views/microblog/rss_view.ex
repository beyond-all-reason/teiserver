defmodule TeiserverWeb.Microblog.RssView do
  use TeiserverWeb, :view

  def format_date(date) do
    date
    |> Calendar.strftime("%Y-%m-%d %I:%M:%S")
  end

  def guid_date(date) do
    date
    |> Calendar.strftime("%Y%m%d%H%M%S")
  end
end
