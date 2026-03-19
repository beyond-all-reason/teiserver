defmodule TeiserverWeb.Report.RatingView do
  use TeiserverWeb, :view

  alias Teiserver.Account.RatingLib

  @spec view_colour :: atom
  def view_colour(), do: RatingLib.colours()

  @spec icon() :: String.t()
  def icon(), do: RatingLib.icon()
end
