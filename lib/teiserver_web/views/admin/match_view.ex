defmodule TeiserverWeb.Admin.MatchView do
  use TeiserverWeb, :view
  import TeiserverWeb.PaginationComponents, only: [pagination: 1]

  alias Teiserver.Battle.MatchLib

  def view_colour(), do: MatchLib.colours()
  def icon(), do: MatchLib.icon()

  @spec calculate_exit_status(integer, integer) :: :abandoned | :early | :noshow | :stayed
  defdelegate calculate_exit_status(left_after, game_duration), to: MatchLib
end
