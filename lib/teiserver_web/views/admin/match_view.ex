defmodule TeiserverWeb.Admin.MatchView do
  use TeiserverWeb, :view
  import TeiserverWeb.PaginationComponents, only: [pagination: 1]

  def view_colour(), do: Teiserver.Battle.MatchLib.colours()
  def icon(), do: Teiserver.Battle.MatchLib.icon()

  @spec calculate_exit_status(integer, integer) :: :abandoned | :early | :noshow | :stayed
  defdelegate calculate_exit_status(left_after, game_duration), to: Teiserver.Battle.MatchLib
end
