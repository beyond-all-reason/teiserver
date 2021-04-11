defmodule TeiserverWeb.Admin.TournamentView do
  use TeiserverWeb, :view

  @spec colours() :: {String.t(), String.t(), String.t()}
  def colours, do: Teiserver.Game.TournamentLib.colours()

  @spec icon() :: String.t()
  def icon, do: Teiserver.Game.TournamentLib.icon()
end
