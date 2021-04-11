defmodule TeiserverWeb.Admin.PartyView do
  use TeiserverWeb, :view

  @spec colours() :: {String.t(), String.t(), String.t()}
  def colours, do: Teiserver.Game.PartyLib.colours()

  @spec icon() :: String.t()
  def icon, do: Teiserver.Game.PartyLib.icon()
end
