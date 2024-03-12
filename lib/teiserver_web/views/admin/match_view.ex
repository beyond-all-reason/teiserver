defmodule BarserverWeb.Admin.MatchView do
  use BarserverWeb, :view

  def view_colour(), do: Barserver.Battle.MatchLib.colours()
  def icon(), do: Barserver.Battle.MatchLib.icon()

  @spec calculate_exit_status(integer, integer) :: :abandoned | :early | :noshow | :stayed
  defdelegate calculate_exit_status(left_after, game_duration), to: Barserver.Battle.MatchLib
end
