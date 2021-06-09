defmodule TeiserverWeb.Battle.BattleLogView do
  use TeiserverWeb, :view

  @spec colours() :: {String.t(), String.t(), String.t()}
  def colours, do: Teiserver.Battle.BattleLogLib.colours()

  @spec icon() :: String.t()
  def icon, do: Teiserver.Battle.BattleLogLib.icon()
end
