defmodule TeiserverWeb.Admin.TextCallbackView do
  use TeiserverWeb, :view

  @spec view_colour() :: atom
  def view_colour, do: Teiserver.Communication.TextCallbackLib.colours()

  @spec icon() :: String.t()
  def icon, do: Teiserver.Communication.TextCallbackLib.icon()
end
