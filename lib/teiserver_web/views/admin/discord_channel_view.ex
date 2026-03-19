defmodule TeiserverWeb.Admin.DiscordChannelView do
  use TeiserverWeb, :view

  alias Teiserver.Communication.DiscordChannelLib

  @spec view_colour() :: atom
  def view_colour, do: DiscordChannelLib.colours()

  @spec icon() :: String.t()
  def icon, do: DiscordChannelLib.icon()
end
