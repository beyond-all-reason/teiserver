defmodule BarserverWeb.Report.RatingView do
  use BarserverWeb, :view

  @spec view_colour :: atom
  def view_colour(), do: Barserver.Account.RatingLib.colours()

  @spec icon() :: String.t()
  def icon(), do: Barserver.Account.RatingLib.icon()
end
