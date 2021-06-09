defmodule TeiserverWeb.Battle.GeneralView do
  use TeiserverWeb, :view

  def colours(), do: StylingHelper.colours(:default)
  def icon(), do: StylingHelper.icon(:default)

  def colours("battle_lobbies"), do: Teiserver.Battle.BattleLobbyLib.colours()
  def colours("battle_logs"), do: Teiserver.Battle.BattleLogLib.colours()
end
