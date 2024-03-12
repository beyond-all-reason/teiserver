defmodule BarserverWeb.Admin.DiscordChannelView do
  use BarserverWeb, :view

  @spec view_colour() :: atom
  def view_colour, do: Barserver.Communication.DiscordChannelLib.colours()

  @spec icon() :: String.t()
  def icon, do: Barserver.Communication.DiscordChannelLib.icon()
end
