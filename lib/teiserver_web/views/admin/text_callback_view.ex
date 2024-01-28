defmodule BarserverWeb.Admin.TextCallbackView do
  use BarserverWeb, :view

  @spec view_colour() :: atom
  def view_colour, do: Barserver.Communication.TextCallbackLib.colours()

  @spec icon() :: String.t()
  def icon, do: Barserver.Communication.TextCallbackLib.icon()
end
