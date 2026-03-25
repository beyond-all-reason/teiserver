defmodule TeiserverWeb.Battle.GeneralView do
  alias Teiserver.Account.PartyLib
  alias Teiserver.Account.RatingLib
  alias Teiserver.Battle.MatchLib
  alias Teiserver.Lobby

  use TeiserverWeb, :view

  def view_colour, do: :default
  def icon, do: StylingHelper.icon(:default)

  def view_colour("battle_lobbies"), do: Lobby.colours()
  def view_colour("matches"), do: MatchLib.colours()
  def view_colour("ratings"), do: RatingLib.colours()
  def view_colour("parties"), do: PartyLib.colours()
end
