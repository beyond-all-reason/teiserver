defmodule TeiserverWeb.Admin.DiscordChannelView do
  alias Teiserver.Communication.DiscordChannelLib

  use TeiserverWeb, :view

  @spec view_colour() :: atom
  def view_colour, do: DiscordChannelLib.colours()

  @spec icon() :: String.t()
  def icon, do: DiscordChannelLib.icon()
end
