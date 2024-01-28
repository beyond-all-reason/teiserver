defmodule BarserverWeb.Battle.GeneralView do
  use BarserverWeb, :view

  def view_colour(), do: :default
  def icon(), do: StylingHelper.icon(:default)

  def view_colour("battle_lobbies"), do: Barserver.Lobby.colours()
  def view_colour("matches"), do: Barserver.Battle.MatchLib.colours()
  def view_colour("ratings"), do: Barserver.Account.RatingLib.colours()
  def view_colour("parties"), do: Barserver.Account.PartyLib.colours()
  def view_colour("matchmaking"), do: Barserver.Game.QueueLib.colours()
  def view_colour("tournaments"), do: :primary
end
