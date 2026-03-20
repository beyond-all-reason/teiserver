defmodule TeiserverWeb.Battle.RatingsView do
  alias Teiserver.Account.RatingLib

  use TeiserverWeb, :view

  @spec view_colour :: atom
  def view_colour(), do: RatingLib.colours()

  @spec icon :: String.t()
  def icon(), do: RatingLib.icon()
end
