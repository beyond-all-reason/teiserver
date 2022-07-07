defmodule TeiserverWeb.Battle.RatingsView do
  use TeiserverWeb, :view

  @spec view_colour :: atom
  def view_colour(), do: Teiserver.Account.RatingLib.colours()

  @spec icon :: String.t()
  def icon(), do: Teiserver.Account.RatingLib.icon()
end
