defmodule TeiserverWeb.Battle.GeneralView do
  use TeiserverWeb, :view

  def view_colour(), do: :default
  def icon(), do: StylingHelper.icon(:default)

  def view_colour("battle_lobbies"), do: Teiserver.Lobby.colours()
  def view_colour("matches"), do: Teiserver.Battle.MatchLib.colours()
  def view_colour("ratings"), do: Teiserver.Account.RatingLib.colours()
  def view_colour("parties"), do: Teiserver.Account.PartyLib.colours()
  def view_colour("tournaments"), do: :primary
end
