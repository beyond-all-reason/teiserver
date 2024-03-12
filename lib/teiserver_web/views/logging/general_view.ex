defmodule BarserverWeb.Logging.GeneralView do
  use BarserverWeb, :view

  @spec view_colour() :: atom
  def view_colour(), do: Barserver.Logging.LoggingLib.colours()

  @spec icon() :: String.t()
  def icon(), do: Barserver.Logging.LoggingLib.icon()

  @spec view_colour(String.t()) :: atom
  def view_colour("page_view"), do: Barserver.Logging.PageViewLogLib.colours()
  def view_colour("aggregate"), do: Barserver.Logging.AggregateViewLogLib.colours()
  def view_colour("audit"), do: Barserver.Logging.AuditLogLib.colours()
  def view_colour("server"), do: Barserver.Logging.ServerDayLogLib.colours()
  def view_colour("match"), do: Barserver.Battle.MatchLib.colours()
end
