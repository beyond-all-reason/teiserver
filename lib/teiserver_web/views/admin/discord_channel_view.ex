defmodule TeiserverWeb.Admin.DiscordChannelView do
  use TeiserverWeb, :view

  @spec view_colour() :: atom
  def view_colour, do: Teiserver.Communication.DiscordChannelLib.colours()

  @spec icon() :: String.t()
  def icon, do: Teiserver.Communication.DiscordChannelLib.icon()
end
